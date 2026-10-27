<?php

namespace App\Modules\Habits\Domain\Evaluation;

use App\Modules\Habits\Domain\Enums\PeriodStatus;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use Carbon\CarbonImmutable;

final class HabitStats
{
    public const int CONSISTENCY_WEEKS = 4;

    public static function windowStart(CarbonImmutable $today): CarbonImmutable
    {
        return HabitCalendar::weekStart($today)->subWeeks(self::CONSISTENCY_WEEKS);
    }

    /**
     * @param  list<Period>  $periods
     * @return array{met: int, total: int}
     */
    public static function tally(array $periods, ?CarbonImmutable $from = null, ?CarbonImmutable $to = null): array
    {
        $met = 0;
        $total = 0;

        foreach ($periods as $period) {
            if (! $period->status->isEvaluable()) {
                continue;
            }

            if (($from !== null && $period->end->lt($from)) || ($to !== null && $period->end->gt($to))) {
                continue;
            }

            $total++;
            $met += $period->isMet() ? 1 : 0;
        }

        return ['met' => $met, 'total' => $total];
    }

    /**
     * @param  array{met: int, total: int}  $tally
     */
    public static function percent(array $tally): ?int
    {
        return $tally['total'] === 0 ? null : (int) round($tally['met'] * 100 / $tally['total']);
    }

    /**
     * @param  list<Period>  $periods
     */
    public static function consistency(array $periods, CarbonImmutable $today): ?int
    {
        return self::percent(self::tally($periods, self::windowStart($today)));
    }

    /**
     * @param  list<Period>  $periods
     */
    public static function streak(array $periods): int
    {
        $streak = 0;

        foreach (array_reverse($periods) as $period) {
            if ($period->status === PeriodStatus::Missed) {
                break;
            }

            $streak += $period->isMet() ? 1 : 0;
        }

        return $streak;
    }

    /**
     * @param  list<Period>  $periods
     * @return array{length: int, end: CarbonImmutable|null}
     */
    public static function bestStreak(array $periods): array
    {
        $best = ['length' => 0, 'end' => null];
        $run = 0;

        foreach ($periods as $period) {
            if ($period->status === PeriodStatus::Missed) {
                $run = 0;

                continue;
            }

            if ($period->isMet()) {
                $run++;

                if ($run > $best['length']) {
                    $best = ['length' => $run, 'end' => $period->end];
                }
            }
        }

        return $best;
    }
}
