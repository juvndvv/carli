<?php

namespace App\Modules\Health\Domain;

use App\Modules\Health\HealthServiceProvider;
use App\Modules\Health\Models\WhoopAccount;
use App\Modules\Health\Models\WhoopCycle;
use App\Modules\Health\Models\WhoopRecovery;
use App\Modules\Health\Models\WhoopSleep;
use App\Modules\Health\Models\WhoopWorkout;
use App\Modules\Health\Notifications\WhoopReconnect;
use App\Modules\Health\Whoop\WhoopAccessRevoked;
use App\Modules\Health\Whoop\WhoopClient;
use App\Modules\Health\Whoop\WhoopException;
use App\Modules\Health\Whoop\WhoopNotFound;
use App\Modules\Health\Whoop\WhoopTokenRejected;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Cache;

/**
 * Copies a member's cycles (strain and steps), recoveries, sleeps and workouts from WHOOP. The scheduled run re-reads the last
 * RESCORE_DAYS (WHOOP rescores and members edit), the first one goes BACKFILL_DAYS back, and webhooks
 * apply single changes in between.
 */
final readonly class WhoopSync
{
    public const int BACKFILL_DAYS = 90;

    public const int RESCORE_DAYS = 4;

    private const string NO_UUID = '00000000-0000-0000-0000-000000000000';

    public function __construct(private WhoopClient $whoop) {}

    /**
     * Syncs an account and records the outcome on it; a revoked grant flags the account and notifies once.
     */
    public function run(WhoopAccount $account): bool
    {
        return $this->guard($account, function () use ($account): void {
            $this->account($account);
        });
    }

    public function account(WhoopAccount $account): void
    {
        $to = CarbonImmutable::now()->addDay();
        $from = $account->synced_at === null
            ? CarbonImmutable::now()->subDays(self::BACKFILL_DAYS)
            : $account->synced_at->subDays(self::RESCORE_DAYS);

        $cycles = $this->withToken($account, fn (string $token) => $this->whoop->collection($token, WhoopClient::CYCLES, $from, $to));
        $sleeps = $this->withToken($account, fn (string $token) => $this->whoop->collection($token, WhoopClient::SLEEPS, $from, $to));
        $recoveries = $this->withToken($account, fn (string $token) => $this->whoop->collection($token, WhoopClient::RECOVERIES, $from, $to));
        $workouts = $this->withToken($account, fn (string $token) => $this->whoop->collection($token, WhoopClient::WORKOUTS, $from, $to));

        $seen = ['cycles' => [], 'sleeps' => [], 'workouts' => []];

        foreach ($cycles as $record) {
            $seen['cycles'][] = $this->storeCycle($account, $record)?->whoop_id;
        }

        foreach ($sleeps as $record) {
            $seen['sleeps'][] = $this->storeSleep($account, $record)?->whoop_id;
        }

        foreach ($recoveries as $record) {
            $this->storeRecovery($account, $record);
        }

        foreach ($workouts as $record) {
            $seen['workouts'][] = $this->storeWorkout($account, $record)?->whoop_id;
        }

        // Whatever started inside the window and WHOOP no longer lists was deleted there.
        WhoopCycle::query()->withoutGlobalScopes()->where('user_id', $account->user_id)->where('starts_at', '>=', $from)->whereNotIn('whoop_id', array_filter($seen['cycles']) ?: [0])->delete();
        WhoopSleep::query()->withoutGlobalScopes()->where('user_id', $account->user_id)->where('starts_at', '>=', $from)->whereNotIn('whoop_id', array_filter($seen['sleeps']) ?: [self::NO_UUID])->delete();
        WhoopWorkout::query()->withoutGlobalScopes()->where('user_id', $account->user_id)->where('starts_at', '>=', $from)->whereNotIn('whoop_id', array_filter($seen['workouts']) ?: [self::NO_UUID])->delete();

        $account->forceFill(['synced_at' => CarbonImmutable::now(), 'last_error' => null, 'status' => WhoopAccount::ACTIVE])->save();
    }

    /**
     * Applies one webhook event: fetches the record again (WHOOP only sends its id) or deletes it.
     */
    public function event(WhoopAccount $account, string $type, string $id): bool
    {
        return $this->guard($account, function () use ($account, $type, $id): void {
            switch ($type) {
                case 'sleep.updated':
                    $this->fetch($account, fn (string $token) => $this->storeSleep($account, $this->whoop->sleep($token, $id)), fn () => $this->deleteSleep($account, $id));
                    break;
                case 'sleep.deleted':
                    $this->deleteSleep($account, $id);
                    break;
                case 'workout.updated':
                    $this->fetch($account, fn (string $token) => $this->storeWorkout($account, $this->whoop->workout($token, $id)), fn () => $this->deleteWorkout($account, $id));
                    break;
                case 'workout.deleted':
                    $this->deleteWorkout($account, $id);
                    break;
                case 'recovery.updated':
                    // v2 sends the id of the sleep the recovery comes from.
                    $this->fetch($account, fn (string $token) => $this->recoveryFromSleep($account, $token, $id), fn () => $this->deleteRecovery($account, $id));
                    break;
                case 'recovery.deleted':
                    $this->deleteRecovery($account, $id);
                    break;
            }
        });
    }

    /**
     * @param  callable(): void  $work
     */
    private function guard(WhoopAccount $account, callable $work): bool
    {
        try {
            $work();

            return true;
        } catch (WhoopAccessRevoked $exception) {
            $wasActive = ! $account->needsReconnect();
            $account->forceFill(['status' => WhoopAccount::RECONNECT, 'last_error' => mb_substr($exception->getMessage(), 0, 500)])->save();

            if ($wasActive) {
                $account->user->notify(new WhoopReconnect);
            }

            return false;
        } catch (WhoopException $exception) {
            $account->forceFill(['last_error' => mb_substr($exception->getMessage(), 0, 500)])->save();

            return false;
        }
    }

    /**
     * @param  callable(string): mixed  $call
     * @param  callable(): mixed  $gone
     */
    private function fetch(WhoopAccount $account, callable $call, callable $gone): void
    {
        try {
            $this->withToken($account, $call);
        } catch (WhoopNotFound) {
            $gone();
        }
    }

    private function recoveryFromSleep(WhoopAccount $account, string $token, string $sleepId): ?WhoopRecovery
    {
        $sleep = $this->storeSleep($account, $this->whoop->sleep($token, $sleepId));

        if ($sleep?->cycle_whoop_id === null) {
            return null;
        }

        $this->storeCycle($account, $this->whoop->cycle($token, $sleep->cycle_whoop_id));

        return $this->storeRecovery($account, $this->whoop->recoveryForCycle($token, $sleep->cycle_whoop_id));
    }

    /**
     * @template T
     *
     * @param  callable(string): T  $call
     * @return T
     */
    private function withToken(WhoopAccount $account, callable $call): mixed
    {
        if ($account->access_token === null || $account->token_expires_at === null || $account->token_expires_at->isPast()) {
            $this->refreshToken($account, $account->access_token);
        }

        try {
            return $call((string) $account->access_token);
        } catch (WhoopTokenRejected) {
            $this->refreshToken($account, $account->access_token);

            return $call((string) $account->access_token);
        }
    }

    /**
     * WHOOP rotates refresh tokens and a second refresh with the old one fails, so the scheduled sync and webhook
     * jobs take turns; whoever comes second reuses the token the first one stored.
     */
    private function refreshToken(WhoopAccount $account, ?string $stale): void
    {
        Cache::lock('health:whoop:refresh:'.$account->id, 30)->block(20, function () use ($account, $stale): void {
            $account->refresh();

            if ($account->access_token !== $stale && $account->token_expires_at?->isFuture() === true) {
                return;
            }

            $tokens = $this->whoop->refresh($account->refresh_token);

            $account->forceFill([
                'access_token' => $tokens['access_token'],
                'token_expires_at' => $tokens['expires_at'],
                'refresh_token' => $tokens['refresh_token'] ?? $account->refresh_token,
            ])->save();
        });
    }

    /**
     * @param  array<string, mixed>  $record
     */
    public function storeCycle(WhoopAccount $account, array $record): ?WhoopCycle
    {
        $start = self::instant($record['start'] ?? null);

        if (! is_int($record['id'] ?? null) || $start === null) {
            return null;
        }

        $offset = self::offset($record);
        $score = self::score($record);
        $localStart = $start->setTimezone($offset);

        return WhoopCycle::query()->withoutGlobalScopes()->updateOrCreate(['user_id' => $account->user_id, 'whoop_id' => $record['id']], [
            'starts_at' => $start,
            'ends_at' => self::instant($record['end'] ?? null),
            // A cycle that opens in the evening (falling asleep) belongs to the next day; one opening in the morning, to that day.
            'day' => ($localStart->hour >= 12 ? $localStart->addDay() : $localStart)->toDateString(),
            'score_state' => (string) ($record['score_state'] ?? 'PENDING_SCORE'),
            'strain' => self::number($score['strain'] ?? null),
            'kilojoule' => self::number($score['kilojoule'] ?? null),
            'average_heart_rate' => self::integer($score['average_heart_rate'] ?? null),
            'max_heart_rate' => self::integer($score['max_heart_rate'] ?? null),
            // Added in September 2026; WHOOP sends it whether or not the cycle is scored yet.
            'step_count' => self::integer($record['step_count'] ?? (is_array($record['score'] ?? null) ? ($record['score']['step_count'] ?? null) : null)),
            'payload' => $record,
        ]);
    }

    /**
     * @param  array<string, mixed>  $record
     */
    public function storeSleep(WhoopAccount $account, array $record): ?WhoopSleep
    {
        $start = self::instant($record['start'] ?? null);
        $end = self::instant($record['end'] ?? null);

        if (! is_string($record['id'] ?? null) || $start === null || $end === null) {
            return null;
        }

        $score = self::score($record);
        $stages = is_array($score['stage_summary'] ?? null) ? $score['stage_summary'] : [];
        $need = is_array($score['sleep_needed'] ?? null) ? $score['sleep_needed'] : [];
        $needParts = array_filter([$need['baseline_milli'] ?? null, $need['need_from_sleep_debt_milli'] ?? null, $need['need_from_recent_strain_milli'] ?? null, $need['need_from_recent_nap_milli'] ?? null], is_int(...));

        return WhoopSleep::query()->withoutGlobalScopes()->updateOrCreate(['user_id' => $account->user_id, 'whoop_id' => $record['id']], [
            'cycle_whoop_id' => self::integer($record['cycle_id'] ?? null),
            'starts_at' => $start,
            'ends_at' => $end,
            // A night belongs to the morning it ends on.
            'day' => $end->setTimezone(self::offset($record))->toDateString(),
            'nap' => ($record['nap'] ?? false) === true,
            'score_state' => (string) ($record['score_state'] ?? 'PENDING_SCORE'),
            'in_bed_milli' => self::integer($stages['total_in_bed_time_milli'] ?? null),
            'awake_milli' => self::integer($stages['total_awake_time_milli'] ?? null),
            'light_milli' => self::integer($stages['total_light_sleep_time_milli'] ?? null),
            'deep_milli' => self::integer($stages['total_slow_wave_sleep_time_milli'] ?? null),
            'rem_milli' => self::integer($stages['total_rem_sleep_time_milli'] ?? null),
            'disturbances' => self::integer($stages['disturbance_count'] ?? null),
            'respiratory_rate' => self::number($score['respiratory_rate'] ?? null),
            'performance_percentage' => self::integer($score['sleep_performance_percentage'] ?? null),
            'consistency_percentage' => self::integer($score['sleep_consistency_percentage'] ?? null),
            'efficiency_percentage' => self::number($score['sleep_efficiency_percentage'] ?? null),
            'need_milli' => $needParts === [] ? null : array_sum($needParts),
            'payload' => $record,
        ]);
    }

    /**
     * @param  array<string, mixed>  $record
     */
    public function storeRecovery(WhoopAccount $account, array $record): ?WhoopRecovery
    {
        if (! is_int($record['cycle_id'] ?? null) || ! is_string($record['sleep_id'] ?? null)) {
            return null;
        }

        $score = self::score($record);

        // A rescore can move the recovery to another sleep of the same cycle.
        WhoopRecovery::query()->withoutGlobalScopes()->where('user_id', $account->user_id)
            ->where('sleep_whoop_id', $record['sleep_id'])->where('cycle_whoop_id', '!=', $record['cycle_id'])->delete();

        return WhoopRecovery::query()->withoutGlobalScopes()->updateOrCreate(['user_id' => $account->user_id, 'cycle_whoop_id' => $record['cycle_id']], [
            'sleep_whoop_id' => $record['sleep_id'],
            'score_state' => (string) ($record['score_state'] ?? 'PENDING_SCORE'),
            'calibrating' => ($score['user_calibrating'] ?? false) === true,
            'recovery_score' => self::integer($score['recovery_score'] ?? null),
            'resting_heart_rate' => self::integer($score['resting_heart_rate'] ?? null),
            'hrv_rmssd_milli' => self::number($score['hrv_rmssd_milli'] ?? null),
            'spo2_percentage' => self::number($score['spo2_percentage'] ?? null),
            'skin_temp_celsius' => self::number($score['skin_temp_celsius'] ?? null),
            'payload' => $record,
        ]);
    }

    /**
     * @param  array<string, mixed>  $record
     */
    public function storeWorkout(WhoopAccount $account, array $record): ?WhoopWorkout
    {
        $start = self::instant($record['start'] ?? null);
        $end = self::instant($record['end'] ?? null);

        if (! is_string($record['id'] ?? null) || $start === null || $end === null) {
            return null;
        }

        $score = self::score($record);
        $zones = is_array($score['zone_durations'] ?? null) ? array_filter($score['zone_durations'], is_int(...)) : null;

        return WhoopWorkout::query()->withoutGlobalScopes()->updateOrCreate(['user_id' => $account->user_id, 'whoop_id' => $record['id']], [
            'starts_at' => $start,
            'ends_at' => $end,
            'day' => $start->setTimezone(self::offset($record))->toDateString(),
            'sport_name' => is_string($record['sport_name'] ?? null) ? $record['sport_name'] : null,
            'score_state' => (string) ($record['score_state'] ?? 'PENDING_SCORE'),
            'strain' => self::number($score['strain'] ?? null),
            'kilojoule' => self::number($score['kilojoule'] ?? null),
            'average_heart_rate' => self::integer($score['average_heart_rate'] ?? null),
            'max_heart_rate' => self::integer($score['max_heart_rate'] ?? null),
            'distance_meter' => self::number($score['distance_meter'] ?? null),
            'zone_durations' => $zones ?: null,
            'payload' => $record,
        ]);
    }

    private function deleteSleep(WhoopAccount $account, string $id): int
    {
        return WhoopSleep::query()->withoutGlobalScopes()->where('user_id', $account->user_id)->where('whoop_id', $id)->delete();
    }

    private function deleteWorkout(WhoopAccount $account, string $id): int
    {
        return WhoopWorkout::query()->withoutGlobalScopes()->where('user_id', $account->user_id)->where('whoop_id', $id)->delete();
    }

    private function deleteRecovery(WhoopAccount $account, string $sleepId): int
    {
        return WhoopRecovery::query()->withoutGlobalScopes()->where('user_id', $account->user_id)->where('sleep_whoop_id', $sleepId)->delete();
    }

    /**
     * @param  array<string, mixed>  $record
     * @return array<string, mixed>
     */
    private static function score(array $record): array
    {
        return ($record['score_state'] ?? null) === 'SCORED' && is_array($record['score'] ?? null) ? $record['score'] : [];
    }

    /**
     * @param  array<string, mixed>  $record
     */
    private static function offset(array $record): string
    {
        $offset = $record['timezone_offset'] ?? null;

        return is_string($offset) && preg_match('/^[+-]\d{2}:\d{2}$/', $offset) === 1 ? $offset : HealthServiceProvider::TIMEZONE;
    }

    private static function instant(mixed $value): ?CarbonImmutable
    {
        return is_string($value) && $value !== '' ? CarbonImmutable::parse($value) : null;
    }

    private static function integer(mixed $value): ?int
    {
        return is_int($value) || is_float($value) ? (int) round($value) : null;
    }

    private static function number(mixed $value): ?float
    {
        return is_int($value) || is_float($value) ? (float) $value : null;
    }
}
