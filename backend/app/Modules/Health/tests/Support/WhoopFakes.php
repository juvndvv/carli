<?php

use App\Modules\Health\Models\WhoopAccount;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

// Shared by the WHOOP feature tests; files run in separate processes under --parallel.

const WHOOP_MEMBER = 10129;
const WHOOP_SLEEP = 'ecfc6a15-4661-442f-a9a4-f160dd7afae8';
const WHOOP_NAP = '1d3e8c9a-52b2-4c4e-9a40-6c1f3b7d2e10';
const WHOOP_WORKOUT = '7bfc6a15-4661-442f-a9a4-f160dd7afae9';

/**
 * @return array<string, list<array<string, mixed>>>
 */
function whoopRecords(): array
{
    return [
        'cycle' => [
            ['id' => 93845, 'user_id' => WHOOP_MEMBER, 'start' => '2026-11-03T22:40:00.000Z', 'end' => null, 'timezone_offset' => '+01:00',
                'step_count' => 6214, 'score_state' => 'SCORED', 'score' => ['strain' => 8.4012, 'kilojoule' => 8288.297, 'average_heart_rate' => 68, 'max_heart_rate' => 141]],
            ['id' => 93844, 'user_id' => WHOOP_MEMBER, 'start' => '2026-11-02T23:05:00.000Z', 'end' => '2026-11-03T22:40:00.000Z', 'timezone_offset' => '+01:00',
                'step_count' => null, 'score_state' => 'SCORED', 'score' => ['strain' => 12.6, 'kilojoule' => 10512.0, 'average_heart_rate' => 72, 'max_heart_rate' => 168]],
        ],
        'sleep' => [
            ['id' => WHOOP_SLEEP, 'cycle_id' => 93845, 'user_id' => WHOOP_MEMBER, 'start' => '2026-11-03T22:40:00.000Z', 'end' => '2026-11-04T06:10:00.000Z',
                'timezone_offset' => '+01:00', 'nap' => false, 'score_state' => 'SCORED', 'score' => [
                    'stage_summary' => ['total_in_bed_time_milli' => 27000000, 'total_awake_time_milli' => 1800000, 'total_no_data_time_milli' => 0,
                        'total_light_sleep_time_milli' => 12600000, 'total_slow_wave_sleep_time_milli' => 5400000, 'total_rem_sleep_time_milli' => 7200000,
                        'sleep_cycle_count' => 4, 'disturbance_count' => 12],
                    'sleep_needed' => ['baseline_milli' => 27720000, 'need_from_sleep_debt_milli' => 1200000, 'need_from_recent_strain_milli' => 600000, 'need_from_recent_nap_milli' => -600000],
                    'respiratory_rate' => 15.3, 'sleep_performance_percentage' => 92, 'sleep_consistency_percentage' => 81, 'sleep_efficiency_percentage' => 93.3,
                ]],
            ['id' => WHOOP_NAP, 'cycle_id' => 93845, 'user_id' => WHOOP_MEMBER, 'start' => '2026-11-04T08:00:00.000Z', 'end' => '2026-11-04T08:35:00.000Z',
                'timezone_offset' => '+01:00', 'nap' => true, 'score_state' => 'SCORED', 'score' => [
                    'stage_summary' => ['total_in_bed_time_milli' => 2100000, 'total_awake_time_milli' => 300000, 'total_light_sleep_time_milli' => 1500000,
                        'total_slow_wave_sleep_time_milli' => 300000, 'total_rem_sleep_time_milli' => 0, 'disturbance_count' => 1],
                ]],
        ],
        'recovery' => [
            ['cycle_id' => 93845, 'sleep_id' => WHOOP_SLEEP, 'user_id' => WHOOP_MEMBER, 'score_state' => 'SCORED', 'score' => [
                'user_calibrating' => false, 'recovery_score' => 74, 'resting_heart_rate' => 52, 'hrv_rmssd_milli' => 61.2341, 'spo2_percentage' => 96.4, 'skin_temp_celsius' => 33.7,
            ]],
        ],
        'workout' => [
            ['id' => WHOOP_WORKOUT, 'user_id' => WHOOP_MEMBER, 'start' => '2026-11-04T07:00:00.000Z', 'end' => '2026-11-04T07:45:00.000Z', 'timezone_offset' => '+01:00',
                'sport_name' => 'running', 'score_state' => 'SCORED', 'score' => [
                    'strain' => 11.2, 'average_heart_rate' => 148, 'max_heart_rate' => 176, 'kilojoule' => 1903.5, 'percent_recorded' => 100, 'distance_meter' => 7210.5,
                    'zone_durations' => ['zone_zero_milli' => 0, 'zone_one_milli' => 120000, 'zone_two_milli' => 600000, 'zone_three_milli' => 1200000, 'zone_four_milli' => 720000, 'zone_five_milli' => 60000],
                ]],
        ],
    ];
}

/**
 * @param  array<string, list<array<string, mixed>>>|null  $records  Collection name => records, as whoopRecords() returns them
 * @param  array<string, mixed>  $token
 */
function fakeWhoop(?array $records = null, array $token = [], string $mode = 'ok'): void
{
    // Http::fake() stacks and the first stub wins, so one callback reads whatever the test set last.
    $GLOBALS['carli_whoop_fake'] = ['records' => $records ?? whoopRecords(), 'token' => $token, 'mode' => $mode];

    if ($GLOBALS['carli_whoop_faked'] ?? false) {
        return;
    }

    $GLOBALS['carli_whoop_faked'] = true;

    Http::fake(function (Request $request) {
        ['records' => $records, 'token' => $token, 'mode' => $mode] = $GLOBALS['carli_whoop_fake'];
        $url = $request->url();
        $path = (string) parse_url($url, PHP_URL_PATH);

        if ($mode === 'down') {
            return Http::response([], 503);
        }

        if ($path === '/oauth/oauth2/token') {
            return $mode === 'revoked'
                ? Http::response(['error' => 'invalid_grant', 'error_description' => 'The refresh token is invalid.'], 400)
                : Http::response($token + ['access_token' => 'access-1', 'refresh_token' => 'refresh-1', 'expires_in' => 3600, 'scope' => 'offline read:profile', 'token_type' => 'bearer']);
        }

        if ($path === '/developer/v2/user/access') {
            return Http::response(null, 204);
        }

        if ($path === '/developer/v2/user/profile/basic') {
            return Http::response(['user_id' => WHOOP_MEMBER, 'email' => 'Juanda@jotade.io', 'first_name' => 'Juanda', 'last_name' => 'D']);
        }

        $collections = ['/developer/v2/cycle' => 'cycle', '/developer/v2/recovery' => 'recovery', '/developer/v2/activity/sleep' => 'sleep', '/developer/v2/activity/workout' => 'workout'];

        if (isset($collections[$path])) {
            return Http::response(['records' => $records[$collections[$path]] ?? [], 'next_token' => null]);
        }

        if (preg_match('#^/developer/v2/cycle/(\d+)/recovery$#', $path, $match)) {
            $found = collect($records['recovery'] ?? [])->firstWhere('cycle_id', (int) $match[1]);

            return $found === null ? Http::response([], 404) : Http::response($found);
        }

        if (preg_match('#^/developer/v2/(cycle|activity/sleep|activity/workout)/([^/]+)$#', $path, $match)) {
            $collection = ['cycle' => 'cycle', 'activity/sleep' => 'sleep', 'activity/workout' => 'workout'][$match[1]];
            $found = collect($records[$collection] ?? [])->first(fn (array $record) => (string) $record['id'] === $match[2]);

            return $found === null ? Http::response([], 404) : Http::response($found);
        }

        return Http::response(['message' => 'unexpected '.$url], 500);
    });
}

function connectWhoop(object $test): WhoopAccount
{
    $url = $test->postJson('/api/v1/health/whoop')->assertOk()->json('data.auth_url');
    parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

    $test->get('/api/v1/health/whoop/callback?'.http_build_query(['state' => $query['state'], 'code' => 'code-1', 'scope' => 'offline']))
        ->assertRedirect('carli://health/whoop?ok=1');

    return WhoopAccount::query()->firstOrFail();
}

/**
 * Posts a webhook signed the way WHOOP signs it.
 *
 * @param  array<string, mixed>  $event
 */
function whoopWebhook(object $test, array $event, ?string $secret = null)
{
    $body = (string) json_encode($event + ['user_id' => WHOOP_MEMBER, 'trace_id' => (string) str()->uuid()]);
    $timestamp = (string) now()->getTimestampMs();
    $signature = base64_encode(hash_hmac('sha256', $timestamp.$body, $secret ?? (string) config('services.whoop.client_secret'), true));

    return $test->call('POST', '/api/v1/health/whoop/webhook', [], [], [], [
        'CONTENT_TYPE' => 'application/json',
        'HTTP_ACCEPT' => 'application/json',
        'HTTP_X_WHOOP_SIGNATURE' => $signature,
        'HTTP_X_WHOOP_SIGNATURE_TIMESTAMP' => $timestamp,
    ], $body);
}
