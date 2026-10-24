<?php

use App\Models\User;

it('exposes the vapid public key', function () {
    config(['webpush.vapid.public_key' => 'BPublicKey', 'webpush.vapid.private_key' => 'secret']);
    $user = User::factory()->create();

    $this->actingAs($user)->getJson('/api/v1/push/public-key')
        ->assertOk()
        ->assertExactJson(['public_key' => 'BPublicKey', 'configured' => true]);
});

it('reports when push is not configured', function () {
    config(['webpush.vapid.public_key' => null, 'webpush.vapid.private_key' => null]);
    $user = User::factory()->create();

    $this->actingAs($user)->getJson('/api/v1/push/public-key')
        ->assertExactJson(['public_key' => null, 'configured' => false]);
});

it('stores and updates a push subscription idempotently', function () {
    $user = User::factory()->create();

    $payload = [
        'endpoint' => 'https://fcm.googleapis.com/fcm/send/abc123',
        'keys' => ['p256dh' => 'BKey', 'auth' => 'AuthToken'],
        'content_encoding' => 'aes128gcm',
    ];

    $this->actingAs($user)->postJson('/api/v1/push-subscriptions', $payload)
        ->assertCreated()
        ->assertJsonPath('data.endpoint', $payload['endpoint']);

    $payload['keys']['auth'] = 'RotatedToken';

    $this->actingAs($user)->postJson('/api/v1/push-subscriptions', $payload)->assertCreated();

    expect($user->pushSubscriptions()->count())->toBe(1)
        ->and($user->pushSubscriptions()->first()->auth_token)->toBe('RotatedToken');
});

it('validates push subscriptions', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/v1/push-subscriptions', ['endpoint' => 'not-a-url'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['endpoint', 'keys']);
});

it('deletes a push subscription', function () {
    $user = User::factory()->create();
    $user->updatePushSubscription('https://push.example.com/xyz', 'key', 'token');

    $this->actingAs($user)->deleteJson('/api/v1/push-subscriptions', ['endpoint' => 'https://push.example.com/xyz'])
        ->assertNoContent();

    expect($user->pushSubscriptions()->count())->toBe(0);
});

it('requires authentication for push endpoints', function () {
    $this->postJson('/api/v1/push-subscriptions', [])->assertUnauthorized();
    $this->getJson('/api/v1/push/public-key')->assertUnauthorized();
});
