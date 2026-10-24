<?php

use App\Core\Sessions\ActiveSessions;
use App\Models\User;
use Illuminate\Support\Facades\DB;

it('returns the authenticated user with default preferences', function () {
    $user = User::factory()->create(['name' => 'Juanda', 'email' => 'juanda@example.com']);

    $this->actingAs($user)->getJson('/api/v1/me')
        ->assertOk()
        ->assertExactJson([
            'data' => [
                'id' => $user->id,
                'name' => 'Juanda',
                'email' => 'juanda@example.com',
                'two_factor_enabled' => false,
                'two_factor_pending' => false,
                'preferences' => ['theme' => 'system', 'sidebar_collapsed' => false],
                'created_at' => $user->created_at->toIso8601String(),
            ],
        ]);
});

it('uses uuid v7 primary keys for users', function () {
    $user = User::factory()->create();

    expect($user->id)->toMatch('/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/');
});

it('updates preferences by merging them', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->patchJson('/api/v1/me/preferences', ['theme' => 'dark'])
        ->assertOk()
        ->assertJsonPath('data.preferences.theme', 'dark');

    $this->actingAs($user)->patchJson('/api/v1/me/preferences', ['sidebar_collapsed' => true])
        ->assertOk()
        ->assertJsonPath('data.preferences.theme', 'dark')
        ->assertJsonPath('data.preferences.sidebar_collapsed', true);

    expect($user->refresh()->preferences)->toBe(['theme' => 'dark', 'sidebar_collapsed' => true]);
});

it('validates the theme preference', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->patchJson('/api/v1/me/preferences', ['theme' => 'sepia'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('theme');
});

it('updates the profile partially', function () {
    $user = User::factory()->create(['name' => 'Old', 'email' => 'old@example.com']);

    $this->actingAs($user)->patchJson('/api/v1/me', ['name' => 'New'])
        ->assertOk()
        ->assertJsonPath('data.name', 'New')
        ->assertJsonPath('data.email', 'old@example.com');
});

it('rejects an email already used by another user', function () {
    User::factory()->create(['email' => 'taken@example.com']);
    $user = User::factory()->create();

    $this->actingAs($user)->patchJson('/api/v1/me', ['email' => 'taken@example.com'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('email');
});

describe('active sessions', function () {
    function coreInsertSession(User $user, string $id, string $userAgent, int $lastActivity): void
    {
        DB::table('sessions')->insert([
            'id' => $id,
            'user_id' => $user->id,
            'ip_address' => '10.0.0.1',
            'user_agent' => $userAgent,
            'payload' => base64_encode(serialize([])),
            'last_activity' => $lastActivity,
        ]);
    }

    it('lists active sessions with device labels', function () {
        $user = User::factory()->create();
        $other = User::factory()->create();

        coreInsertSession($user, 'session-mac', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15', now()->subMinutes(5)->timestamp);
        coreInsertSession($user, 'session-android', 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36', now()->timestamp);
        coreInsertSession($other, 'session-foreign', 'Firefox/130.0', now()->timestamp);

        $this->actingAs($user)->withHeader('Origin', 'http://localhost:4200')->getJson('/api/v1/me/sessions')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', ActiveSessions::publicId('session-android'))
            ->assertJsonPath('data.0.device', 'Chrome en Android')
            ->assertJsonPath('data.0.is_mobile', true)
            ->assertJsonPath('data.1.device', 'Safari en macOS')
            ->assertJsonPath('data.1.is_current', false);
    });

    it('logs out other devices after confirming the password', function () {
        $user = User::factory()->create();
        $other = User::factory()->create();

        coreInsertSession($user, 'session-a', 'Chrome/140.0', now()->timestamp);
        coreInsertSession($user, 'session-b', 'Chrome/140.0', now()->timestamp);
        coreInsertSession($other, 'session-foreign', 'Chrome/140.0', now()->timestamp);

        $this->actingAs($user)->postJson('/api/v1/me/sessions/logout-others', ['password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');

        $this->actingAs($user)->postJson('/api/v1/me/sessions/logout-others', ['password' => 'password'])
            ->assertOk()
            ->assertJson(['revoked' => 2]);

        expect(DB::table('sessions')->where('user_id', $user->id)->count())->toBe(0)
            ->and(DB::table('sessions')->where('user_id', $other->id)->count())->toBe(1);
    });

    it('revokes a single session by its public id', function () {
        $user = User::factory()->create();
        $other = User::factory()->create();

        coreInsertSession($user, 'session-a', 'Chrome/140.0', now()->timestamp);
        coreInsertSession($other, 'session-foreign', 'Chrome/140.0', now()->timestamp);

        $this->actingAs($user)->deleteJson('/api/v1/me/sessions/'.ActiveSessions::publicId('session-foreign'))
            ->assertNotFound();

        $this->actingAs($user)->deleteJson('/api/v1/me/sessions/'.ActiveSessions::publicId('session-a'))
            ->assertNoContent();

        expect(DB::table('sessions')->where('id', 'session-a')->exists())->toBeFalse();
    });
});
