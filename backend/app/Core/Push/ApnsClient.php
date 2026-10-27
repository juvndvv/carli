<?php

namespace App\Core\Push;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

final class ApnsClient
{
    private const int TOKEN_TTL_SECONDS = 50 * 60;

    private const array UNREGISTERED_REASONS = ['BadDeviceToken', 'DeviceTokenNotForTopic', 'Unregistered'];

    public function send(string $deviceToken, ApnsEnvironment $environment, ApnsMessage $message): ApnsDelivery
    {
        try {
            $response = Http::withOptions(['version' => 2.0])
                ->withToken($this->providerToken(), 'bearer')
                ->withHeaders([
                    'apns-topic' => ApnsConfiguration::bundleId(),
                    'apns-push-type' => 'alert',
                    'apns-priority' => '10',
                ])
                ->timeout(ApnsConfiguration::timeoutSeconds())
                ->post("{$environment->host()}/3/device/{$deviceToken}", $message->payload());
        } catch (ConnectionException $exception) {
            Log::warning('APNs request failed', ['error' => $exception->getMessage()]);

            return ApnsDelivery::Failed;
        }

        if ($response->successful()) {
            return ApnsDelivery::Delivered;
        }

        $reason = $response->json('reason');

        if ($response->status() === 410 || in_array($reason, self::UNREGISTERED_REASONS, true)) {
            return ApnsDelivery::Unregistered;
        }

        if ($response->status() === 403 && $reason === 'ExpiredProviderToken') {
            Cache::forget($this->cacheKey());
        }

        Log::warning('APNs rejected a notification', ['status' => $response->status(), 'reason' => $reason]);

        return ApnsDelivery::Failed;
    }

    private function providerToken(): string
    {
        /** @var string */
        return Cache::remember($this->cacheKey(), self::TOKEN_TTL_SECONDS, fn () => $this->signProviderToken());
    }

    private function cacheKey(): string
    {
        return 'apns:provider-token:'.ApnsConfiguration::teamId().':'.ApnsConfiguration::keyId();
    }

    private function signProviderToken(): string
    {
        $privateKey = openssl_pkey_get_private((string) ApnsConfiguration::privateKey());

        if ($privateKey === false) {
            throw new RuntimeException('The APNs private key could not be read.');
        }

        $header = self::base64Url((string) json_encode(['alg' => 'ES256', 'kid' => ApnsConfiguration::keyId()]));
        $claims = self::base64Url((string) json_encode(['iss' => ApnsConfiguration::teamId(), 'iat' => time()]));

        if (! openssl_sign("{$header}.{$claims}", $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('The APNs provider token could not be signed.');
        }

        return "{$header}.{$claims}.".self::base64Url(self::derToRawSignature($signature));
    }

    private static function derToRawSignature(string $der): string
    {
        $rLength = ord($der[3]);
        $r = substr($der, 4, $rLength);
        $sLength = ord($der[5 + $rLength]);
        $s = substr($der, 6 + $rLength, $sLength);

        return self::padInteger($r).self::padInteger($s);
    }

    private static function padInteger(string $integer): string
    {
        return str_pad(ltrim($integer, "\0"), 32, "\0", STR_PAD_LEFT);
    }

    private static function base64Url(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
