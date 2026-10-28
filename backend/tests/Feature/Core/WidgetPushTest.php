<?php

use App\Core\Notifications\TestNotification;
use App\Core\Push\ApnsClient;
use App\Core\Push\RefreshWidgets;
use App\Models\User;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    configureApns();
    $this->user = User::factory()->create();
});

it('registers widget tokens apart from the app tokens', function () {
    $this->actingAs($this->user)->postJson('/api/v1/push-devices', [
        'token' => str_repeat('C3', 32), 'environment' => 'sandbox', 'kind' => 'widgets',
    ])->assertCreated();

    expect($this->user->pushDevices()->count())->toBe(0)
        ->and($this->user->widgetPushDevices()->sole()->token)->toBe(str_repeat('c3', 32));
});

it('never sends alerts to widget tokens', function () {
    Http::fake(['*' => Http::response()]);
    $this->user->pushDevices()->create(['token' => str_repeat('a1', 32), 'environment' => 'sandbox']);
    $this->user->widgetPushDevices()->create(['token' => str_repeat('c3', 32), 'environment' => 'sandbox', 'kind' => 'widgets']);

    $this->user->notify(new TestNotification);

    Http::assertSentCount(1);
    Http::assertSent(fn (Request $request) => str_ends_with($request->url(), str_repeat('a1', 32)));
});

it('asks the widgets to reload and forgets tokens apple no longer accepts', function () {
    Http::fake([
        '*/'.str_repeat('c3', 32) => Http::response(),
        '*/'.str_repeat('d4', 32) => Http::response(['reason' => 'Unregistered'], 410),
    ]);
    $this->user->pushDevices()->create(['token' => str_repeat('a1', 32), 'environment' => 'sandbox']);
    $this->user->widgetPushDevices()->create(['token' => str_repeat('c3', 32), 'environment' => 'production', 'kind' => 'widgets']);
    $this->user->widgetPushDevices()->create(['token' => str_repeat('d4', 32), 'environment' => 'sandbox', 'kind' => 'widgets']);

    (new RefreshWidgets($this->user->id))->handle(app(ApnsClient::class));

    Http::assertSentCount(2);
    Http::assertSent(fn (Request $request) => $request->url() === 'https://api.push.apple.com/3/device/'.str_repeat('c3', 32)
        && $request->header('apns-topic') === ['dev.jotade.personal.push-type.widgets']
        && $request->header('apns-push-type') === ['widgets']
        && $request->data() === ['aps' => ['content-changed' => true]]);
    expect($this->user->widgetPushDevices()->pluck('token')->all())->toBe([str_repeat('c3', 32)])
        ->and($this->user->pushDevices()->count())->toBe(1);
});
