<?php

use App\Models\User;
use Laravel\Fortify\Contracts\TwoFactorAuthenticationProvider;
use Laravel\Sanctum\PersonalAccessToken;
use PragmaRX\Google2FA\Google2FA;

function enableTwoFactor(User $user): string
{
    $secret = app(TwoFactorAuthenticationProvider::class)->generateSecretKey();

    $user->forceFill([
        'two_factor_secret' => encrypt($secret),
        'two_factor_recovery_codes' => encrypt(json_encode(['recovery-code-1', 'recovery-code-2'])),
        'two_factor_confirmed_at' => now(),
    ])->save();

    return $secret;
}

it('issues a personal access token for valid credentials', function () {
    $user = User::factory()->create(['email' => 'juanda@example.com']);

    $response = $this->postJson('/api/v1/auth/token', [
        'email' => 'Juanda@Example.com',
        'password' => 'password',
        'device_name' => 'iPhone de Juanda',
    ])->assertCreated()
        ->assertJsonPath('user.id', $user->id)
        ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email']]);

    expect($user->tokens()->sole()->name)->toBe('iPhone de Juanda');

    $this->withToken($response->json('token'))
        ->getJson('/api/v1/me')
        ->assertOk()
        ->assertJsonPath('data.id', $user->id);
});

it('does not start a session when issuing a token', function () {
    User::factory()->create(['email' => 'juanda@example.com']);

    $this->postJson('/api/v1/auth/token', [
        'email' => 'juanda@example.com',
        'password' => 'password',
        'device_name' => 'iPhone',
    ])->assertCreated();

    $this->assertGuest('web');
});

it('rejects invalid credentials', function () {
    $user = User::factory()->create(['email' => 'juanda@example.com']);

    $this->postJson('/api/v1/auth/token', [
        'email' => 'juanda@example.com',
        'password' => 'wrong-password',
        'device_name' => 'iPhone',
    ])->assertUnprocessable()->assertJsonValidationErrors('email');

    expect($user->tokens()->count())->toBe(0);
});

it('requires a device name', function () {
    User::factory()->create(['email' => 'juanda@example.com']);

    $this->postJson('/api/v1/auth/token', ['email' => 'juanda@example.com', 'password' => 'password'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('device_name');
});

it('throttles token requests after five attempts per minute', function () {
    User::factory()->create(['email' => 'juanda@example.com']);

    foreach (range(1, 5) as $attempt) {
        $this->postJson('/api/v1/auth/token', [
            'email' => 'juanda@example.com',
            'password' => 'wrong',
            'device_name' => 'iPhone',
        ])->assertUnprocessable();
    }

    $this->postJson('/api/v1/auth/token', [
        'email' => 'juanda@example.com',
        'password' => 'password',
        'device_name' => 'iPhone',
    ])->assertTooManyRequests();
});

describe('two factor authentication', function () {
    it('asks for a code instead of issuing a token', function () {
        $user = User::factory()->create(['email' => 'secure@example.com']);
        enableTwoFactor($user);

        $this->postJson('/api/v1/auth/token', [
            'email' => 'secure@example.com',
            'password' => 'password',
            'device_name' => 'iPhone',
        ])->assertOk()->assertExactJson(['two_factor' => true]);

        expect($user->tokens()->count())->toBe(0);
    });

    it('issues a token with a valid code', function () {
        $user = User::factory()->create(['email' => 'secure@example.com']);
        $secret = enableTwoFactor($user);

        $this->postJson('/api/v1/auth/token', [
            'email' => 'secure@example.com',
            'password' => 'password',
            'device_name' => 'iPhone',
            'code' => (new Google2FA)->getCurrentOtp($secret),
        ])->assertCreated()->assertJsonStructure(['token']);
    });

    it('rejects an invalid code', function () {
        $user = User::factory()->create(['email' => 'secure@example.com']);
        enableTwoFactor($user);

        $this->postJson('/api/v1/auth/token', [
            'email' => 'secure@example.com',
            'password' => 'password',
            'device_name' => 'iPhone',
            'code' => '000000',
        ])->assertUnprocessable()->assertJsonValidationErrors('code');

        expect($user->tokens()->count())->toBe(0);
    });

    it('accepts a recovery code only once', function () {
        $user = User::factory()->create(['email' => 'secure@example.com']);
        enableTwoFactor($user);

        $payload = [
            'email' => 'secure@example.com',
            'password' => 'password',
            'device_name' => 'iPhone',
            'recovery_code' => 'recovery-code-1',
        ];

        $this->postJson('/api/v1/auth/token', $payload)->assertCreated();

        $this->postJson('/api/v1/auth/token', $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('recovery_code');
    });
});

it('revokes the current token on logout', function () {
    $user = User::factory()->create();
    $current = $user->createToken('iPhone')->plainTextToken;
    $user->createToken('iPad');

    $this->withToken($current)->deleteJson('/api/v1/auth/token')->assertNoContent();

    expect($user->tokens()->pluck('name')->all())->toBe(['iPad'])
        ->and(PersonalAccessToken::findToken($current))->toBeNull();
});

it('requires authentication to revoke a token', function () {
    $this->deleteJson('/api/v1/auth/token')->assertUnauthorized();
});

it('keeps the session when a cookie authenticated client calls token logout', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->deleteJson('/api/v1/auth/token')->assertNoContent();

    $this->assertAuthenticatedAs($user);
});
