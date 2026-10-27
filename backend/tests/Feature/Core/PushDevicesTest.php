<?php

use App\Models\User;

it('registers a device token once and moves it to the current user', function () {
    configureApns();
    $previous = User::factory()->create();
    $user = User::factory()->create();
    $token = str_repeat('AB', 32);

    $this->actingAs($previous)->postJson('/api/v1/push-devices', ['token' => $token, 'environment' => 'sandbox'])
        ->assertCreated();

    $this->actingAs($user)->postJson('/api/v1/push-devices', ['token' => $token, 'environment' => 'production'])
        ->assertCreated()
        ->assertJsonPath('data.environment', 'production')
        ->assertJsonPath('push_configured', true);

    expect($previous->pushDevices()->count())->toBe(0)
        ->and($user->pushDevices()->sole()->token)->toBe(strtolower($token));
});

it('validates device tokens', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/v1/push-devices', ['token' => 'not-hex', 'environment' => 'staging'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['token', 'environment']);
});

it('removes a device token', function () {
    $user = User::factory()->create();
    $user->pushDevices()->create(['token' => str_repeat('ef', 32), 'environment' => 'sandbox']);

    $this->actingAs($user)->deleteJson('/api/v1/push-devices', ['token' => str_repeat('EF', 32)])
        ->assertNoContent();

    expect($user->pushDevices()->count())->toBe(0);
});
