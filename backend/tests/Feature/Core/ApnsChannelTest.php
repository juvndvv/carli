<?php

use App\Core\Notifications\TestNotification;
use App\Models\User;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    configureApns();
    $this->user = User::factory()->create();
    $this->sandbox = $this->user->pushDevices()->create(['token' => str_repeat('a1', 32), 'environment' => 'sandbox']);
    $this->production = $this->user->pushDevices()->create(['token' => str_repeat('b2', 32), 'environment' => 'production']);
});

function apnsSegment(string $segment): string
{
    return (string) base64_decode(strtr($segment, '-_', '+/'));
}

function apnsRawSignatureToDer(string $raw): string
{
    $integer = function (string $bytes): string {
        $bytes = ltrim($bytes, "\0");
        $bytes = ord($bytes[0]) & 0x80 ? "\0".$bytes : $bytes;

        return "\x02".chr(strlen($bytes)).$bytes;
    };
    $sequence = $integer(substr($raw, 0, 32)).$integer(substr($raw, 32));

    return "\x30".chr(strlen($sequence)).$sequence;
}

it('sends an alert to every device of the user through its apns environment', function () {
    Http::fake(['*' => Http::response()]);

    $this->user->notify(new TestNotification);

    $inboxId = $this->user->notifications()->sole()->id;

    Http::assertSentCount(2);
    Http::assertSent(fn (Request $request) => $request->url() === 'https://api.sandbox.push.apple.com/3/device/'.str_repeat('a1', 32));
    Http::assertSent(function (Request $request) use ($inboxId) {
        return $request->url() === 'https://api.push.apple.com/3/device/'.str_repeat('b2', 32)
            && $request->header('apns-topic') === ['dev.jotade.personal']
            && $request->header('apns-push-type') === ['alert']
            && $request->data() === [
                'aps' => [
                    'alert' => ['title' => 'Notificación de prueba', 'body' => 'Si ves esto, las notificaciones funcionan correctamente.'],
                    'sound' => 'default',
                ],
                'url' => '/ajustes',
                'notification_id' => $inboxId,
            ];
    });
});

it('signs the provider token with the apns key', function () {
    Http::fake(['*' => Http::response()]);

    $this->user->notify(new TestNotification);

    $authorization = Http::recorded()->first()[0]->header('Authorization')[0];
    [$header, $claims, $signature] = explode('.', substr($authorization, strlen('bearer ')));
    $raw = apnsSegment($signature);
    $publicKey = openssl_pkey_get_details(openssl_pkey_get_private((string) file_get_contents(config('services.apns.private_key_path'))))['key'];

    expect(json_decode(apnsSegment($header), true))->toBe(['alg' => 'ES256', 'kid' => 'KEYID12345'])
        ->and(json_decode(apnsSegment($claims), true)['iss'])->toBe('S5FFHKW385')
        ->and(strlen($raw))->toBe(64)
        ->and(openssl_verify("{$header}.{$claims}", apnsRawSignatureToDer($raw), $publicKey, OPENSSL_ALGO_SHA256))->toBe(1);
});

it('forgets devices that apns reports as unregistered', function () {
    Http::fake([
        'api.sandbox.push.apple.com/*' => Http::response(['reason' => 'BadDeviceToken'], 400),
        'api.push.apple.com/*' => Http::response(['reason' => 'Unregistered'], 410),
    ]);

    $this->user->notify(new TestNotification);

    expect($this->user->pushDevices()->count())->toBe(0);
});

it('keeps devices when apns fails for other reasons', function () {
    Http::fake(['*' => Http::response(['reason' => 'InternalServerError'], 500)]);

    $this->user->notify(new TestNotification);

    expect($this->user->pushDevices()->count())->toBe(2);
});
