<?php

namespace App\Modules\Calendar\Google;

use Carbon\CarbonImmutable;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;

/**
 * The few Google endpoints carli needs: OAuth (web server flow) and Calendar API v3, read-only.
 */
final class GoogleClient
{
    public const string SCOPE = 'https://www.googleapis.com/auth/calendar.readonly';

    private const string AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';

    private const string TOKEN_URL = 'https://oauth2.googleapis.com/token';

    private const string REVOKE_URL = 'https://oauth2.googleapis.com/revoke';

    private const string API = 'https://www.googleapis.com/calendar/v3';

    public function configured(): bool
    {
        return filled(config('services.google.client_id')) && filled(config('services.google.client_secret'));
    }

    public function authUrl(string $state): string
    {
        $this->ensureConfigured();

        return self::AUTH_URL.'?'.http_build_query([
            'client_id' => config('services.google.client_id'),
            'redirect_uri' => config('services.google.redirect_url'),
            'response_type' => 'code',
            'scope' => self::SCOPE,
            'access_type' => 'offline',
            // Always ask, so Google returns a refresh token even for an account linked before.
            'prompt' => 'consent select_account',
            'include_granted_scopes' => 'true',
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
            'redirect_uri' => config('services.google.redirect_url'),
        ]);
    }

    /**
     * @return array{access_token: string, refresh_token: string|null, expires_at: CarbonImmutable, scope: string}
     */
    public function refresh(string $refreshToken): array
    {
        $this->ensureConfigured();

        return $this->token(['grant_type' => 'refresh_token', 'refresh_token' => $refreshToken]);
    }

    public function revoke(string $token): void
    {
        try {
            $this->http()->asForm()->post(self::REVOKE_URL, ['token' => $token]);
        } catch (ConnectionException) {
            // Best effort: the account is forgotten here anyway.
        }
    }

    /**
     * Every calendar the account can see, as Google lists them.
     *
     * @return list<array<string, mixed>>
     */
    public function calendars(string $accessToken): array
    {
        return $this->paginate($accessToken, '/users/me/calendarList', ['minAccessRole' => 'reader', 'showHidden' => 'false']);
    }

    /**
     * Event instances (recurring ones expanded) that overlap [from, to).
     *
     * @return list<array<string, mixed>>
     */
    public function events(string $accessToken, string $calendarId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return $this->paginate($accessToken, '/calendars/'.rawurlencode($calendarId).'/events', [
            'singleEvents' => 'true',
            'orderBy' => 'startTime',
            'timeMin' => $from->toRfc3339String(),
            'timeMax' => $to->toRfc3339String(),
            'maxResults' => 2500,
            'showDeleted' => 'false',
        ]);
    }

    /**
     * @param  array<string, string>  $form
     * @return array{access_token: string, refresh_token: string|null, expires_at: CarbonImmutable, scope: string}
     */
    private function token(array $form): array
    {
        try {
            $response = $this->http()->asForm()->post(self::TOKEN_URL, $form + [
                'client_id' => config('services.google.client_id'),
                'client_secret' => config('services.google.client_secret'),
            ]);
        } catch (ConnectionException $exception) {
            throw new GoogleException('Google token endpoint unreachable: '.$exception->getMessage(), previous: $exception);
        }

        if ($response->status() === 400 && $response->json('error') === 'invalid_grant') {
            throw new GoogleAccessRevoked('Google rejected the grant: '.$response->json('error_description', 'invalid_grant'));
        }

        if ($response->failed() || ! is_string($response->json('access_token'))) {
            throw new GoogleException('Google token request failed ('.$response->status().'): '.$response->json('error', 'unknown'));
        }

        $refresh = $response->json('refresh_token');

        return [
            'access_token' => (string) $response->json('access_token'),
            'refresh_token' => is_string($refresh) ? $refresh : null,
            'expires_at' => CarbonImmutable::now()->addSeconds(max(60, (int) $response->json('expires_in', 3600)) - 60),
            'scope' => (string) $response->json('scope', ''),
        ];
    }

    /**
     * @param  array<string, mixed>  $query
     * @return list<array<string, mixed>>
     */
    private function paginate(string $accessToken, string $path, array $query): array
    {
        $items = [];
        $pageToken = null;

        do {
            $response = $this->get($accessToken, $path, $query + ($pageToken !== null ? ['pageToken' => $pageToken] : []));

            foreach ((array) $response->json('items', []) as $item) {
                if (is_array($item)) {
                    $items[] = $item;
                }
            }

            $next = $response->json('nextPageToken');
            $pageToken = is_string($next) && $next !== '' ? $next : null;
        } while ($pageToken !== null);

        return $items;
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function get(string $accessToken, string $path, array $query): Response
    {
        try {
            $response = $this->http()->withToken($accessToken)->get(self::API.$path, $query);
        } catch (ConnectionException $exception) {
            throw new GoogleException('Google Calendar unreachable: '.$exception->getMessage(), previous: $exception);
        }

        if ($response->status() === 401) {
            throw new GoogleTokenRejected('Google Calendar refused the access token.');
        }

        if ($response->failed()) {
            throw new GoogleException('Google Calendar request failed ('.$response->status().'): '.$response->json('error.message', 'unknown'));
        }

        return $response;
    }

    private function http(): PendingRequest
    {
        return Http::acceptJson()->timeout((int) config('services.google.timeout', 20));
    }

    private function ensureConfigured(): void
    {
        if (! $this->configured()) {
            throw new GoogleNotConfigured('Google Calendar is not configured: set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.');
        }
    }
}
