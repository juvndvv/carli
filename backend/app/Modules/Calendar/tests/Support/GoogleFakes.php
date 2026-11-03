<?php

use App\Modules\Calendar\Models\GoogleAccount;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

// Shared by the Calendar feature tests; files run in separate processes under --parallel.

if (! defined('GOOGLE_SCOPE')) {
    define('GOOGLE_SCOPE', 'https://www.googleapis.com/auth/calendar.readonly');
}

/**
 * @param  array<string, list<array<string, mixed>>>  $events  google calendar id => events
 * @param  array<string, mixed>  $token
 */
function fakeGoogle(array $events = [], array $token = [], ?array $calendars = null, string $mode = 'ok'): void
{
    $calendars ??= [
        ['id' => 'juanda@jotade.io', 'summary' => 'juanda@jotade.io', 'backgroundColor' => '#9fe1e7', 'primary' => true, 'selected' => true, 'accessRole' => 'owner'],
        ['id' => 'family@group.calendar.google.com', 'summary' => 'Familia', 'backgroundColor' => '#f691b2', 'selected' => true, 'accessRole' => 'writer'],
        ['id' => 'es.spain#holiday@group.v.calendar.google.com', 'summary' => 'Festivos en España', 'backgroundColor' => '#16a765', 'accessRole' => 'reader'],
    ];

    // Http::fake() stacks and the first stub wins, so one callback reads whatever the test set last.
    $GLOBALS['carli_google_fake'] = compact('events', 'token', 'calendars', 'mode');

    if ($GLOBALS['carli_google_faked'] ?? false) {
        return;
    }

    $GLOBALS['carli_google_faked'] = true;

    Http::fake(function (Request $request) {
        ['events' => $events, 'token' => $token, 'calendars' => $calendars, 'mode' => $mode] = $GLOBALS['carli_google_fake'];
        $url = $request->url();

        if ($mode === 'down') {
            return Http::response([], 503);
        }

        if (str_starts_with($url, 'https://oauth2.googleapis.com/token')) {
            return $mode === 'revoked'
                ? Http::response(['error' => 'invalid_grant', 'error_description' => 'Token has been expired or revoked.'], 400)
                : Http::response($token + ['access_token' => 'access-1', 'refresh_token' => 'refresh-1', 'expires_in' => 3599, 'scope' => GOOGLE_SCOPE, 'token_type' => 'Bearer']);
        }

        if (str_starts_with($url, 'https://oauth2.googleapis.com/revoke')) {
            return Http::response([]);
        }

        if (str_contains($url, '/users/me/calendarList')) {
            return Http::response(['items' => $calendars]);
        }

        if (preg_match('#/calendars/([^/]+)/events#', $url, $match)) {
            return Http::response(['items' => $events[rawurldecode($match[1])] ?? []]);
        }

        return Http::response(['error' => ['message' => 'unexpected '.$url]], 500);
    });
}

function googleEvents(): array
{
    return [
        'juanda@jotade.io' => [
            ['id' => 'dentist', 'status' => 'confirmed', 'summary' => 'Dentista', 'location' => 'Calle Mayor 3', 'htmlLink' => 'https://calendar.google.com/e/dentist',
                'start' => ['dateTime' => '2026-11-04T09:30:00+01:00'], 'end' => ['dateTime' => '2026-11-04T10:15:00+01:00']],
            ['id' => 'trip', 'status' => 'confirmed', 'summary' => 'Viaje a Lisboa', 'start' => ['date' => '2026-11-06'], 'end' => ['date' => '2026-11-09']],
            ['id' => 'declined', 'status' => 'confirmed', 'summary' => 'Reunión rechazada', 'start' => ['dateTime' => '2026-11-04T12:00:00+01:00'], 'end' => ['dateTime' => '2026-11-04T13:00:00+01:00'],
                'attendees' => [['email' => 'juanda@jotade.io', 'self' => true, 'responseStatus' => 'declined']]],
            ['id' => 'cancelled', 'status' => 'cancelled'],
            ['id' => 'utc', 'status' => 'confirmed', 'summary' => 'Llamada', 'start' => ['dateTime' => '2026-11-05T17:00:00Z'], 'end' => ['dateTime' => '2026-11-05T17:30:00Z']],
        ],
        'family@group.calendar.google.com' => [
            ['id' => 'dinner', 'status' => 'confirmed', 'summary' => 'Cena familiar', 'start' => ['dateTime' => '2026-11-04T21:00:00+01:00'], 'end' => ['dateTime' => '2026-11-05T00:00:00+01:00']],
        ],
    ];
}

function connectGoogle(object $test): GoogleAccount
{
    $url = $test->postJson('/api/v1/calendar/google/accounts')->assertOk()->json('data.auth_url');
    parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

    $test->get('/api/v1/calendar/google/callback?'.http_build_query(['state' => $query['state'], 'code' => 'code-1', 'scope' => GOOGLE_SCOPE]))
        ->assertRedirectContains('carli://calendar/google?account=');

    return GoogleAccount::query()->firstOrFail();
}
