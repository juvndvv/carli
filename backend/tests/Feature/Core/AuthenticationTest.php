<?php

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Laravel\Fortify\Contracts\TwoFactorAuthenticationProvider;
use PragmaRX\Google2FA\Google2FA;

beforeEach(function () {
    RateLimiter::clear('login');
});

it('logs in with valid credentials', function () {
    $user = User::factory()->create(['email' => 'juanda@example.com']);

    $this->postJson('/login', ['email' => 'juanda@example.com', 'password' => 'password'])
        ->assertOk()
        ->assertJson(['two_factor' => false]);

    $this->assertAuthenticatedAs($user);
});

it('rejects invalid credentials', function () {
    User::factory()->create(['email' => 'juanda@example.com']);

    $this->postJson('/login', ['email' => 'juanda@example.com', 'password' => 'wrong-password'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('email');

    $this->assertGuest();
});

it('throttles login attempts after five failures per minute', function () {
    User::factory()->create(['email' => 'juanda@example.com']);

    foreach (range(1, 5) as $attempt) {
        $this->postJson('/login', ['email' => 'juanda@example.com', 'password' => 'wrong'])->assertUnprocessable();
    }

    $this->postJson('/login', ['email' => 'juanda@example.com', 'password' => 'password'])
        ->assertTooManyRequests();
});

it('logs out', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/logout')->assertNoContent();

    $this->assertGuest('web');
});

it('does not expose public registration', function () {
    $this->postJson('/register', [
        'name' => 'Intruder',
        'email' => 'intruder@example.com',
        'password' => 'password',
        'password_confirmation' => 'password',
    ])->assertNotFound();
});

it('returns 401 json for unauthenticated api requests', function () {
    $this->getJson('/api/v1/me')->assertUnauthorized();
    $this->get('/api/v1/me')->assertUnauthorized();
});

it('serves the csrf cookie endpoint', function () {
    $this->get('/sanctum/csrf-cookie')->assertNoContent()->assertCookie('XSRF-TOKEN');
});

it('authenticates stateful spa requests through the session cookie flow', function () {
    $user = User::factory()->create(['email' => 'spa@example.com']);

    $this->withHeader('Origin', 'http://localhost:4200')
        ->postJson('/login', ['email' => 'spa@example.com', 'password' => 'password'])
        ->assertOk();

    $this->withHeader('Origin', 'http://localhost:4200')
        ->getJson('/api/v1/me')
        ->assertOk()
        ->assertJsonPath('data.id', $user->id);
});

it('updates the password through fortify', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->putJson('/user/password', [
        'current_password' => 'password',
        'password' => 'a-new-Secure-passw0rd',
        'password_confirmation' => 'a-new-Secure-passw0rd',
    ])->assertOk();

    expect(Hash::check('a-new-Secure-passw0rd', $user->refresh()->password))->toBeTrue();
});

it('rejects a password update with a wrong current password', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->putJson('/user/password', [
        'current_password' => 'nope',
        'password' => 'a-new-Secure-passw0rd',
        'password_confirmation' => 'a-new-Secure-passw0rd',
    ])->assertUnprocessable()->assertJsonValidationErrors('current_password');
});

it('updates profile information through fortify', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->putJson('/user/profile-information', [
        'name' => 'Juanda',
        'email' => 'juanda@example.com',
    ])->assertOk();

    expect($user->refresh())->name->toBe('Juanda')->email->toBe('juanda@example.com');
});

describe('two factor authentication', function () {
    it('requires password confirmation before enabling', function () {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/user/two-factor-authentication')->assertStatus(423);
    });

    it('enables, confirms and disables two factor authentication', function () {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/user/confirm-password', ['password' => 'password'])->assertCreated();

        $this->actingAs($user)
            ->withSession(['auth.password_confirmed_at' => time()])
            ->postJson('/user/two-factor-authentication')
            ->assertOk();

        $user->refresh();
        expect($user->two_factor_secret)->not->toBeNull()
            ->and($user->two_factor_confirmed_at)->toBeNull();

        $this->actingAs($user)
            ->withSession(['auth.password_confirmed_at' => time()])
            ->getJson('/user/two-factor-qr-code')
            ->assertOk()
            ->assertJsonStructure(['svg', 'url']);

        $this->actingAs($user)
            ->withSession(['auth.password_confirmed_at' => time()])
            ->getJson('/api/v1/me')
            ->assertJsonPath('data.two_factor_enabled', false)
            ->assertJsonPath('data.two_factor_pending', true);

        $code = (new Google2FA)->getCurrentOtp(decrypt($user->two_factor_secret));

        $this->actingAs($user)
            ->withSession(['auth.password_confirmed_at' => time()])
            ->postJson('/user/confirmed-two-factor-authentication', ['code' => $code])
            ->assertOk();

        expect($user->refresh()->two_factor_confirmed_at)->not->toBeNull();

        $this->actingAs($user)
            ->withSession(['auth.password_confirmed_at' => time()])
            ->getJson('/user/two-factor-recovery-codes')
            ->assertOk()
            ->assertJsonCount(8);

        $this->actingAs($user)
            ->withSession(['auth.password_confirmed_at' => time()])
            ->deleteJson('/user/two-factor-authentication')
            ->assertOk();

        expect($user->refresh())
            ->two_factor_secret->toBeNull()
            ->two_factor_confirmed_at->toBeNull();
    });

    it('asks for a two factor challenge on login and accepts a valid code', function () {
        $provider = app(TwoFactorAuthenticationProvider::class);
        $secret = $provider->generateSecretKey();

        $user = User::factory()->create(['email' => 'secure@example.com']);
        $user->forceFill([
            'two_factor_secret' => encrypt($secret),
            'two_factor_recovery_codes' => encrypt(json_encode(['recovery-code-1', 'recovery-code-2'])),
            'two_factor_confirmed_at' => now(),
        ])->save();

        $this->postJson('/login', ['email' => 'secure@example.com', 'password' => 'password'])
            ->assertOk()
            ->assertJson(['two_factor' => true]);

        $this->assertGuest();

        $this->withSession(['login.id' => $user->id, 'login.remember' => false])
            ->postJson('/two-factor-challenge', ['code' => (new Google2FA)->getCurrentOtp($secret)])
            ->assertNoContent();

        $this->assertAuthenticatedAs($user);
    });

    it('accepts a recovery code once', function () {
        $user = User::factory()->create();
        $user->forceFill([
            'two_factor_secret' => encrypt(app(TwoFactorAuthenticationProvider::class)->generateSecretKey()),
            'two_factor_recovery_codes' => encrypt(json_encode(['recovery-code-1', 'recovery-code-2'])),
            'two_factor_confirmed_at' => now(),
        ])->save();

        $this->withSession(['login.id' => $user->id, 'login.remember' => false])
            ->postJson('/two-factor-challenge', ['recovery_code' => 'recovery-code-1'])
            ->assertNoContent();

        $this->assertAuthenticatedAs($user);
        expect($user->refresh()->recoveryCodes())->not->toContain('recovery-code-1');
    });

    it('rejects an invalid two factor code', function () {
        $user = User::factory()->create();
        $user->forceFill([
            'two_factor_secret' => encrypt(app(TwoFactorAuthenticationProvider::class)->generateSecretKey()),
            'two_factor_recovery_codes' => encrypt(json_encode(['recovery-code-1'])),
            'two_factor_confirmed_at' => now(),
        ])->save();

        $this->withSession(['login.id' => $user->id, 'login.remember' => false])
            ->postJson('/two-factor-challenge', ['code' => '000000'])
            ->assertUnprocessable();

        $this->assertGuest();
    });
});
