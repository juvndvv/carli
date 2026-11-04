<?php

namespace App\Modules\Health\Whoop;

use Carbon\CarbonImmutable;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;

/**
 * The WHOOP developer API v2: OAuth (authorization code with refresh tokens that rotate) and the read endpoints.
 * WHOOP only shares summaries (steps per cycle included); there is no continuous heart rate.
 */
final class WhoopClient
{
    /** @var list<string> */
    public const array SCOPES = ['offline', 'read:profile', 'read:cycles', 'read:recovery', 'read:sleep', 'read:workout'];

    public const string CYCLES = '/v2/cycle';

    public const string RECOVERIES = '/v2/recovery';

    public const string SLEEPS = '/v2/activity/sleep';

    public const string WORKOUTS = '/v2/activity/workout';

    private const string AUTH_URL = 'https://api.prod.whoop.com/oauth/oauth2/auth';

    private const string TOKEN_URL = 'https://api.prod.whoop.com/oauth/oauth2/token';

    private const string API = 'https://api.prod.whoop.com/developer';

    /** The largest page WHOOP serves. */
    private const int PAGE = 25;

    public function configured(): bool
    {
        return filled(config('services.whoop.client_id')) && filled(config('services.whoop.client_secret'));
    }

    public function authUrl(string $state): string
    {
        $this->ensureConfigured();

        return self::AUTH_URL.'?'.http_build_query([
            'client_id' => config('services.whoop.client_id'),
            'redirect_uri' => config('services.whoop.redirect_url'),
            'response_type' => 'code',
            'scope' => implode(' ', self::SCOPES),
            'state' => $state,
        ]);
    }

    /**
     * @return array{access_token: string, refresh_token: string|null, expires_at: CarbonImmutable, scope: string}
     */
    public function exchangeCode(string $code): array
    {
        $this->ensureConfigured();

        return $this->token([
            'grant_type' => 'authorization_code',
            'code' => $code,
            'redirect_uri' => config('services.whoop.redirect_url'),
        ]);
    }

    /**
     * The old refresh token stops working as soon as this succeeds: store the new one.
     *
     * @return array{access_token: string, refresh_token: string|null, expires_at: CarbonImmutable, scope: string}
     */
    public function refresh(string $refreshToken): array
    {
        $this->ensureConfigured();

        return $this->token(['grant_type' => 'refresh_token', 'refresh_token' => $refreshToken, 'scope' => 'offline']);
    }

    public function revoke(string $accessToken): void
    {
        try {
            $this->http()->withToken($accessToken)->delete(self::API.'/v2/user/access');
        } catch (ConnectionException) {
            // Best effort: the account is forgotten here anyway.
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function profile(string $accessToken): array
    {
        return (array) $this->get($accessToken, '/v2/user/profile/basic')->json();
    }

    /**
     * Every record of a collection (CYCLES, RECOVERIES, SLEEPS or WORKOUTS) that starts inside [from, to).
     *
     * @return list<array<string, mixed>>
     */
    public function collection(string $accessToken, string $path, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $records = [];
        $nextToken = null;

        do {
            $query = ['limit' => self::PAGE, 'start' => $from->utc()->toIso8601ZuluString('millisecond'), 'end' => $to->utc()->toIso8601ZuluString('millisecond')];
            $response = $this->get($accessToken, $path, $query + ($nextToken !== null ? ['nextToken' => $nextToken] : []));

            foreach ((array) $response->json('records', []) as $record) {
                if (is_array($record)) {
                    $records[] = $record;
                }
            }

            $next = $response->json('next_token');
            $nextToken = is_string($next) && $next !== '' ? $next : null;
        } while ($nextToken !== null);

        return $records;
    }

    /**
     * @return array<string, mixed>
     */
    public function sleep(string $accessToken, string $id): array
    {
        return (array) $this->get($accessToken, self::SLEEPS.'/'.rawurlencode($id))->json();
    }

    /**
     * @return array<string, mixed>
     */
    public function workout(string $accessToken, string $id): array
    {
        return (array) $this->get($accessToken, self::WORKOUTS.'/'.rawurlencode($id))->json();
    }

    /**
     * @return array<string, mixed>
     */
    public function cycle(string $accessToken, int $id): array
    {
        return (array) $this->get($accessToken, self::CYCLES.'/'.$id)->json();
    }

    /**
     * @return array<string, mixed>
     */
    public function recoveryForCycle(string $accessToken, int $cycleId): array
    {
        return (array) $this->get($accessToken, self::CYCLES.'/'.$cycleId.'/recovery')->json();
    }

    /**
     * Webhooks sign base64(HMAC-SHA256(timestamp + raw body, client secret)).
     */
    public function validSignature(string $body, ?string $timestamp, ?string $signature): bool
    {
        $secret = config('services.whoop.client_secret');

        if (! is_string($secret) || $secret === '' || ! is_string($timestamp) || $timestamp === '' || ! is_string($signature) || $signature === '') {
            return false;
        }

        return hash_equals(base64_encode(hash_hmac('sha256', $timestamp.$body, $secret, true)), $signature);
    }

    /**
     * @param  array<string, string>  $form
     * @return array{access_token: string, refresh_token: string|null, expires_at: CarbonImmutable, scope: string}
     */
    private function token(array $form): array
    {
        try {
            $response = $this->http()->asForm()->post(self::TOKEN_URL, $form + [
                'client_id' => config('services.whoop.client_id'),
                'client_secret' => config('services.whoop.client_secret'),
            ]);
        } catch (ConnectionException $exception) {
            throw new WhoopException('WHOOP token endpoint unreachable: '.$exception->getMessage(), previous: $exception);
        }

        if (in_array($response->status(), [400, 401], true) && $response->json('error') === 'invalid_grant') {
            throw new WhoopAccessRevoked('WHOOP rejected the grant: '.$response->json('error_description', $response->json('error')));
        }

        if ($response->failed() || ! is_string($response->json('access_token'))) {
            throw new WhoopException('WHOOP token request failed ('.$response->status().'): '.$response->json('error', 'unknown'));
        }

        $refresh = $response->json('refresh_token');

        return [
            'access_token' => (string) $response->json('access_token'),
            'refresh_token' => is_string($refresh) ? $refresh : null,
            'expires_at' => CarbonImmutable::now()->addSeconds(max(120, (int) $response->json('expires_in', 3600)) - 60),
            'scope' => (string) $response->json('scope', ''),
        ];
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function get(string $accessToken, string $path, array $query = []): Response
    {
        try {
            $response = $this->http()->withToken($accessToken)->get(self::API.$path, $query);
        } catch (ConnectionException $exception) {
            throw new WhoopException('WHOOP unreachable: '.$exception->getMessage(), previous: $exception);
        }

        if ($response->status() === 401) {
            throw new WhoopTokenRejected('WHOOP refused the access token.');
        }

        if ($response->status() === 404) {
            throw new WhoopNotFound('WHOOP has no '.$path.'.');
        }

        if ($response->failed()) {
            throw new WhoopException('WHOOP request failed ('.$response->status().') on '.$path.'.');
        }

        return $response;
    }

    private function http(): PendingRequest
    {
        return Http::acceptJson()->timeout((int) config('services.whoop.timeout', 20));
    }

    private function ensureConfigured(): void
    {
        if (! $this->configured()) {
            throw new WhoopNotConfigured('WHOOP is not configured: set WHOOP_CLIENT_ID and WHOOP_CLIENT_SECRET.');
        }
    }
}
