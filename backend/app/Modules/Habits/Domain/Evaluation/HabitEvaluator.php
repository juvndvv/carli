<?php

namespace App\Modules\Habits\Domain\Evaluation;

use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Enums\PeriodStatus;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use Carbon\CarbonImmutable;

final class HabitEvaluator
{
    private const int DAYS_PER_WEEK = 7;

    /**
     * @return list<Period>
     */
    public function periods(Timeline $timeline, CarbonImmutable $today): array
    {
        $last = $timeline->lastTrackedDay($today);
        $periods = [];
        $day = $timeline->start;

        while ($day->lte($last)) {
            $goal = $timeline->goalOn($day);

            if ($goal->period === GoalPeriod::Day) {
                $periods[] = $this->day($timeline, $goal, $day, $today);
                $day = $day->addDay();

                continue;
            }

            $end = $this->weekEnd($timeline, $day);
            $periods[] = $this->week($timeline, $day, $end, $today);
            $day = $end->addDay();
        }

        return $periods;
    }

    public function periodOn(Timeline $timeline, CarbonImmutable $today, ?CarbonImmutable $day = null): ?Period
    {
        $day ??= $today;

        foreach (array_reverse($this->periods($timeline, $today)) as $period) {
            if ($period->contains($day)) {
                return $period;
            }
        }

        return null;
    }

    private function weekEnd(Timeline $timeline, CarbonImmutable $from): CarbonImmutable
    {
        $end = HabitCalendar::weekEnd($from);

        for ($probe = $from->addDay(); $probe->lte($end); $probe = $probe->addDay()) {
            if ($timeline->goalOn($probe)->period === GoalPeriod::Day) {
                return $probe->subDay();
            }
        }

        return $end;
    }

    private function day(Timeline $timeline, Goal $goal, CarbonImmutable $day, CarbonImmutable $today): Period
    {
        $value = $timeline->valueOn($day);

        $status = match (true) {
            ! $goal->includes($day) => PeriodStatus::Off,
            $timeline->isOnBreak($day) => PeriodStatus::Excused,
            default => $this->status($timeline->kind, $value, $goal->target, closed: $day->lt($today)),
        };

        return new Period($day, $day, GoalPeriod::Day, $goal, $goal->target, $value, $status);
    }

    private function week(Timeline $timeline, CarbonImmutable $start, CarbonImmutable $end, CarbonImmutable $today): Period
    {
        $goal = $timeline->goalOn($end->min($today));
        $available = 0;
        $value = 0.0;

        for ($day = $start; $day->lte($end); $day = $day->addDay()) {
            if ($timeline->isTracked($day) && ! $timeline->isOnBreak($day)) {
                $available++;
            }

            if ($day->lte($today)) {
                $logged = $timeline->valueOn($day);
                $value += $timeline->kind === HabitKind::Check ? ($logged > 0 ? 1.0 : 0.0) : $logged;
            }
        }

        $target = $this->prorate($timeline->kind, $goal->target, $available);
        $closed = $end->lt($today) || $timeline->stop !== null;

        $status = $available === 0
            ? PeriodStatus::Excused
            : $this->status($timeline->kind, $value, $target, $closed);

        return new Period($start, $end, GoalPeriod::Week, $goal, $target, $value, $status);
    }

    private function prorate(HabitKind $kind, float $target, int $available): float
    {
        if ($available >= self::DAYS_PER_WEEK) {
            return $target;
        }

        return match ($kind) {
            HabitKind::Check => min($target, (float) $available),
            HabitKind::Quantity => round($target * $available / self::DAYS_PER_WEEK, 2),
            HabitKind::Avoid => $target,
        };
    }

    private function status(HabitKind $kind, float $value, float $target, bool $closed): PeriodStatus
    {
        if ($kind === HabitKind::Avoid) {
            return match (true) {
                $value > $target + 0.0001 => PeriodStatus::Missed,
                $closed => PeriodStatus::Met,
                default => PeriodStatus::Current,
            };
        }

        return match (true) {
            $value + 0.0001 >= $target => PeriodStatus::Met,
            $closed => PeriodStatus::Missed,
            default => PeriodStatus::Current,
        };
    }
}
