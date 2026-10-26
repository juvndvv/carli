<?php

use App\Core\Sessions\ActiveSessions;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Laravel\Fortify\Contracts\TwoFactorAuthenticationProvider;
use Laravel\Sanctum\NewAccessToken;
use PragmaRX\Google2FA\Google2FA;

function securityToken(User $user, string $name = 'carli iOS'): NewAccessToken
{
    return $user->createToken($name);
}

function securityConfirmedTwoFactor(User $user): void
{
    $user->forceFill([
        'two_factor_secret' => encrypt(app(TwoFactorAuthenticationProvider::class)->generateSecretKey()),
        'two_factor_recovery_codes' => encrypt(json_encode(['code-one', 'code-two'])),
        'two_factor_confirmed_at' => now(),
    ])->save();
}

function securityInsertSession(User $user, string $id): void
{
    DB::table('sessions')->insert([
        'id' => $id,
        'user_id' => $user->id,
        'ip_address' => '10.0.0.1',
        'user_agent' => 'Chrome/140.0',
        'payload' => base64_encode(serialize([])),
        'last_activity' => now()->timestamp,
    ]);
}

describe('password', function () {
    it('updates the password with a bearer token', function () {
        $user = User::factory()->create();

        $this->withToken(securityToken($user)->plainTextToken)
            ->putJson('/api/v1/me/password', [
                'current_password' => 'password',
                'password' => 'a-new-Secret-42',
                'password_confirmation' => 'a-new-Secret-42',
            ])->assertNoContent();

        expect(Hash::check('a-new-Secret-42', $user->refresh()->password))->toBeTrue();
    });

    it('rejects a wrong current password', function () {
        $user = User::factory()->create();

        $this->withToken(securityToken($user)->plainTextToken)
            ->putJson('/api/v1/me/password', [
                'current_password' => 'wrong',
                'password' => 'a-new-Secret-42',
                'password_confirmation' => 'a-new-Secret-42',
            ])->assertUnprocessable()
            ->assertJsonValidationErrors(['current_password' => 'La contraseña no coincide con tu contraseña actual.']);

        expect(Hash::check('password', $user->refresh()->password))->toBeTrue();
    });

    it('requires a confirmed new password', function () {
        $user = User::factory()->create();

        $this->withToken(securityToken($user)->plainTextToken)
            ->putJson('/api/v1/me/password', [
                'current_password' => 'password',
                'password' => 'a-new-Secret-42',
                'password_confirmation' => 'something-else',
            ])->assertUnprocessable()
            ->assertJsonValidationErrors('password');
    });

    it('requires authentication', function () {
        $this->putJson('/api/v1/me/password', [])->assertUnauthorized();
    });
});

describe('two factor authentication', function () {
    it('enables two factor authentication pending confirmation', function () {
        $user = User::factory()->create(['email' => 'juanda@example.com']);

        $response = $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor', ['password' => 'password'])
            ->assertOk()
            ->assertJsonStructure(['secret_key', 'qr_code_url', 'qr_code_svg']);

        $user->refresh();

        expect($response->json('qr_code_url'))->toStartWith('otpauth://totp/')
            ->and($response->json('secret_key'))->toBe(decrypt((string) $user->two_factor_secret))
            ->and($user->two_factor_confirmed_at)->toBeNull();

        $this->getJson('/api/v1/me')->assertJsonPath('data.two_factor_pending', true);
    });

    it('keeps the pending secret when enabling again', function () {
        $user = User::factory()->create();
        $token = securityToken($user)->plainTextToken;

        $first = $this->withToken($token)->postJson('/api/v1/me/two-factor', ['password' => 'password'])->json('secret_key');
        $second = $this->withToken($token)->postJson('/api/v1/me/two-factor', ['password' => 'password'])->json('secret_key');

        expect($second)->toBe($first);
    });

    it('requires the current password to enable', function () {
        $user = User::factory()->create();

        $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor', ['password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');

        expect($user->refresh()->two_factor_secret)->toBeNull();
    });

    it('refuses to enable when already confirmed', function () {
        $user = User::factory()->create();
        securityConfirmedTwoFactor($user);

        $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor', ['password' => 'password'])
            ->assertConflict();
    });

    it('confirms with a valid code and returns the recovery codes', function () {
        $user = User::factory()->create();
        $token = securityToken($user)->plainTextToken;

        $secret = $this->withToken($token)->postJson('/api/v1/me/two-factor', ['password' => 'password'])->json('secret_key');

        $codes = $this->withToken($token)
            ->postJson('/api/v1/me/two-factor/confirm', ['code' => (new Google2FA)->getCurrentOtp($secret)])
            ->assertOk()
            ->assertJsonCount(8, 'recovery_codes')
            ->json('recovery_codes');

        $user->refresh();

        expect($user->two_factor_confirmed_at)->not->toBeNull()
            ->and($codes)->toBe($user->recoveryCodes());
    });

    it('rejects an invalid confirmation code', function () {
        $user = User::factory()->create();
        $token = securityToken($user)->plainTextToken;

        $this->withToken($token)->postJson('/api/v1/me/two-factor', ['password' => 'password']);

        $this->withToken($token)
            ->postJson('/api/v1/me/two-factor/confirm', ['code' => '000000'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['code' => 'El código de verificación no es válido.']);

        expect($user->refresh()->two_factor_confirmed_at)->toBeNull();
    });

    it('refuses to confirm before enabling', function () {
        $user = User::factory()->create();

        $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor/confirm', ['code' => '123456'])
            ->assertConflict();
    });

    it('disables two factor authentication with the current password', function () {
        $user = User::factory()->create();
        securityConfirmedTwoFactor($user);
        $token = securityToken($user)->plainTextToken;

        $this->withToken($token)
            ->deleteJson('/api/v1/me/two-factor', ['password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');

        $this->withToken($token)
            ->deleteJson('/api/v1/me/two-factor', ['password' => 'password'])
            ->assertNoContent();

        $user->refresh();

        expect($user->two_factor_secret)->toBeNull()
            ->and($user->two_factor_confirmed_at)->toBeNull();
    });

    it('shows the recovery codes with the current password', function () {
        $user = User::factory()->create();
        securityConfirmedTwoFactor($user);

        $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor/recovery-codes', ['password' => 'password'])
            ->assertOk()
            ->assertExactJson(['recovery_codes' => ['code-one', 'code-two']]);
    });

    it('regenerates the recovery codes with the current password', function () {
        $user = User::factory()->create();
        securityConfirmedTwoFactor($user);

        $codes = $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor/recovery-codes/regenerate', ['password' => 'password'])
            ->assertOk()
            ->assertJsonCount(8, 'recovery_codes')
            ->json('recovery_codes');

        expect($codes)->not->toContain('code-one')
            ->and($user->refresh()->recoveryCodes())->toBe($codes);
    });

    it('protects the recovery codes with the current password', function () {
        $user = User::factory()->create();
        securityConfirmedTwoFactor($user);

        $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor/recovery-codes', ['password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');
    });

    it('refuses recovery codes while two factor authentication is not confirmed', function () {
        $user = User::factory()->create();

        $this->withToken(securityToken($user)->plainTextToken)
            ->postJson('/api/v1/me/two-factor/recovery-codes', ['password' => 'password'])
            ->assertConflict();
    });
});

describe('personal access tokens', function () {
    it('lists the user tokens and flags the current one', function () {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $current = securityToken($user);
        $ipad = securityToken($user, 'iPad');
        securityToken($other, 'Foreign');

        $this->withToken($current->plainTextToken)
            ->getJson('/api/v1/me/tokens')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $current->accessToken->id)
            ->assertJsonPath('data.0.name', 'carli iOS')
            ->assertJsonPath('data.0.is_current', true)
            ->assertJsonPath('data.1.id', $ipad->accessToken->id)
            ->assertJsonPath('data.1.is_current', false)
            ->assertJsonPath('data.1.last_used_at', null)
            ->assertJsonStructure(['data' => [['id', 'name', 'last_used_at', 'created_at', 'is_current']]]);
    });

    it('revokes another token of the user', function () {
        $user = User::factory()->create();
        $current = securityToken($user);
        $ipad = securityToken($user, 'iPad');

        $this->withToken($current->plainTextToken)
            ->deleteJson('/api/v1/me/tokens/'.$ipad->accessToken->id)
            ->assertNoContent();

        expect($user->tokens()->pluck('name')->all())->toBe(['carli iOS']);
    });

    it('does not revoke the current token', function () {
        $user = User::factory()->create();
        $current = securityToken($user);

        $this->withToken($current->plainTextToken)
            ->deleteJson('/api/v1/me/tokens/'.$current->accessToken->id)
            ->assertConflict();

        expect($user->tokens()->count())->toBe(1);
    });

    it('returns not found for tokens of other users', function () {
        $user = User::factory()->create();
        $foreign = securityToken(User::factory()->create(), 'Foreign');

        $this->withToken(securityToken($user)->plainTextToken)
            ->deleteJson('/api/v1/me/tokens/'.$foreign->accessToken->id)
            ->assertNotFound();

        expect($foreign->accessToken->fresh())->not->toBeNull();
    });

    it('logs out every other token and web session after confirming the password', function () {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $current = securityToken($user);
        securityToken($user, 'iPad');
        $foreign = securityToken($other, 'Foreign');
        securityInsertSession($user, 'session-a');
        securityInsertSession($other, 'session-foreign');

        $this->withToken($current->plainTextToken)
            ->postJson('/api/v1/me/tokens/logout-others', ['password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');

        $this->withToken($current->plainTextToken)
            ->postJson('/api/v1/me/tokens/logout-others', ['password' => 'password'])
            ->assertOk()
            ->assertExactJson(['revoked_tokens' => 1, 'revoked_sessions' => 1]);

        expect($user->tokens()->pluck('name')->all())->toBe(['carli iOS'])
            ->and($foreign->accessToken->fresh())->not->toBeNull()
            ->and(DB::table('sessions')->where('user_id', $user->id)->count())->toBe(0)
            ->and(DB::table('sessions')->where('user_id', $other->id)->count())->toBe(1);
    });

    it('lets the native app revoke a web session', function () {
        $user = User::factory()->create();
        securityInsertSession($user, 'session-a');

        $this->withToken(securityToken($user)->plainTextToken)
            ->deleteJson('/api/v1/me/sessions/'.ActiveSessions::publicId('session-a'))
            ->assertNoContent();

        expect(DB::table('sessions')->where('user_id', $user->id)->count())->toBe(0);
    });
});
