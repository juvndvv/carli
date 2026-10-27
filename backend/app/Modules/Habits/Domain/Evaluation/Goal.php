<?php

namespace App\Modules\Habits\Domain\Evaluation;

use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Models\HabitGoal;
use Carbon\CarbonImmutable;

final readonly class Goal
{
    /**
     * @param  list<int>|null  $daysOfWeek
     */
    public function __construct(
        public CarbonImmutable $validFrom,
        public GoalPeriod $period,
        public float $target,
        public ?array $daysOfWeek = null,
    ) {}

    public static function fromModel(HabitGoal $goal): self
    {
        return new self($goal->valid_from, $goal->period, $goal->target, $goal->days_of_week);
    }

    public function includes(CarbonImmutable $day): bool
    {
        return $this->daysOfWeek === null || in_array($day->dayOfWeekIso, $this->daysOfWeek, true);
    }

    public function sameAs(self $other): bool
    {
        return $this->period === $other->period
            && abs($this->target - $other->target) < 0.001
            && $this->daysOfWeek === $other->daysOfWeek;
    }
}
