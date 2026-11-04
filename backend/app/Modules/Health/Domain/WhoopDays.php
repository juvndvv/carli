<?php

namespace App\Modules\Health\Domain;

use App\Models\User;
use App\Modules\Health\Models\WhoopCycle;
use App\Modules\Health\Models\WhoopRecovery;
use App\Modules\Health\Models\WhoopSleep;
use App\Modules\Health\Models\WhoopWorkout;
use Carbon\CarbonImmutable;

/**
 * Groups the copied WHOOP records by day: the recovery and the night that end on it, its strain and steps, and its workouts.
 */
final class WhoopDays
{
    /** @var list<class-string<WhoopCycle|WhoopRecovery|WhoopSleep|WhoopWorkout>> */
    public const array MODELS = [WhoopCycle::class, WhoopRecovery::class, WhoopSleep::class, WhoopWorkout::class];

    /**
     * Days in [from, to] that have something, newest first.
     *
     * @return list<array<string, mixed>>
     */
    public function between(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $range = [$from->toDateString(), $to->toDateString()];

        $sleeps = WhoopSleep::query()->withoutGlobalScopes()->where('user_id', $user->id)->whereBetween('day', $range)->orderBy('starts_at')->get();
        $cycles = WhoopCycle::query()->withoutGlobalScopes()->where('user_id', $user->id)->whereBetween('day', $range)->orderBy('starts_at')->get();
        $workouts = WhoopWorkout::query()->withoutGlobalScopes()->where('user_id', $user->id)->whereBetween('day', $range)->orderBy('starts_at')->get();
        $recoveries = WhoopRecovery::query()->withoutGlobalScopes()->where('user_id', $user->id)
            ->where(fn ($query) => $query->whereIn('sleep_whoop_id', $sleeps->pluck('whoop_id')->all() ?: ['00000000-0000-0000-0000-000000000000'])
                ->orWhereIn('cycle_whoop_id', $cycles->pluck('whoop_id')->all() ?: [0]))
            ->get();

        $days = [];

        foreach ($sleeps as $sleep) {
            $date = $sleep->day->toDateString();
            $days[$date] ??= self::blank($date);

            if ($sleep->nap) {
                $days[$date]['nap_minutes'] += self::minutes($sleep->asleepMilli()) ?? 0;
            } else {
                // The last main sleep that ends on the day is the night.
                $days[$date]['sleep'] = self::sleep($sleep);
            }
        }

        foreach ($cycles as $cycle) {
            $date = $cycle->day->toDateString();
            $days[$date] ??= self::blank($date);
            $days[$date]['strain'] = self::strain($cycle);
        }

        foreach ($workouts as $workout) {
            $date = $workout->day->toDateString();
            $days[$date] ??= self::blank($date);
            $days[$date]['workouts'][] = self::workout($workout);
        }

        $sleepDays = $sleeps->mapWithKeys(fn (WhoopSleep $sleep) => [$sleep->whoop_id => $sleep->day->toDateString()]);
        $cycleDays = $cycles->mapWithKeys(fn (WhoopCycle $cycle) => [$cycle->whoop_id => $cycle->day->toDateString()]);

        foreach ($recoveries as $recovery) {
            $date = $sleepDays[$recovery->sleep_whoop_id] ?? $cycleDays[$recovery->cycle_whoop_id] ?? null;

            if (is_string($date)) {
                $days[$date] ??= self::blank($date);
                $days[$date]['recovery'] = self::recovery($recovery);
            }
        }

        krsort($days);

        return array_values($days);
    }

    /**
     * @return array{date: string, recovery: array<string, mixed>|null, sleep: array<string, mixed>|null, nap_minutes: int, strain: array<string, mixed>|null, workouts: list<array<string, mixed>>}
     */
    private static function blank(string $date): array
    {
        return ['date' => $date, 'recovery' => null, 'sleep' => null, 'nap_minutes' => 0, 'strain' => null, 'workouts' => []];
    }

    /**
     * @return array<string, mixed>
     */
    public static function recovery(WhoopRecovery $recovery): array
    {
        return [
            'state' => $recovery->score_state,
            'calibrating' => $recovery->calibrating,
            'score' => $recovery->recovery_score,
            'resting_heart_rate' => $recovery->resting_heart_rate,
            'hrv_ms' => self::float($recovery->hrv_rmssd_milli),
            'spo2' => self::float($recovery->spo2_percentage),
            'skin_temp_c' => self::float($recovery->skin_temp_celsius),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public static function sleep(WhoopSleep $sleep): array
    {
        return [
            'state' => $sleep->score_state,
            'starts_at' => $sleep->starts_at->toIso8601String(),
            'ends_at' => $sleep->ends_at->toIso8601String(),
            'asleep_minutes' => self::minutes($sleep->asleepMilli()),
            'in_bed_minutes' => self::minutes($sleep->in_bed_milli),
            'awake_minutes' => self::minutes($sleep->awake_milli),
            'light_minutes' => self::minutes($sleep->light_milli),
            'deep_minutes' => self::minutes($sleep->deep_milli),
            'rem_minutes' => self::minutes($sleep->rem_milli),
            'need_minutes' => self::minutes($sleep->need_milli),
            'performance' => $sleep->performance_percentage,
            'consistency' => $sleep->consistency_percentage,
            'efficiency' => self::float($sleep->efficiency_percentage),
            'respiratory_rate' => self::float($sleep->respiratory_rate),
            'disturbances' => $sleep->disturbances,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public static function strain(WhoopCycle $cycle): array
    {
        return [
            'state' => $cycle->score_state,
            'in_progress' => $cycle->ends_at === null,
            'strain' => self::float($cycle->strain),
            'kcal' => self::kcal($cycle->kilojoule),
            'average_heart_rate' => $cycle->average_heart_rate,
            'max_heart_rate' => $cycle->max_heart_rate,
            'steps' => $cycle->step_count,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public static function workout(WhoopWorkout $workout): array
    {
        $zones = $workout->zone_durations ?? [];

        return [
            'id' => $workout->id,
            'state' => $workout->score_state,
            'sport' => $workout->sport_name,
            'starts_at' => $workout->starts_at->toIso8601String(),
            'ends_at' => $workout->ends_at->toIso8601String(),
            'strain' => self::float($workout->strain),
            'kcal' => self::kcal($workout->kilojoule),
            'average_heart_rate' => $workout->average_heart_rate,
            'max_heart_rate' => $workout->max_heart_rate,
            'distance_m' => self::float($workout->distance_meter),
            'zone_minutes' => array_map(
                fn (string $zone) => self::minutes($zones["zone_{$zone}_milli"] ?? null) ?? 0,
                ['zero', 'one', 'two', 'three', 'four', 'five'],
            ),
        ];
    }

    private static function minutes(?int $milli): ?int
    {
        return $milli === null ? null : (int) round($milli / 60000);
    }

    private static function float(?string $value): ?float
    {
        return $value === null ? null : (float) $value;
    }

    private static function kcal(?string $kilojoule): ?int
    {
        return $kilojoule === null ? null : (int) round((float) $kilojoule / 4.184);
    }
}
