<?php

namespace App\Modules\Habits\Domain\Evaluation;

use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\PeriodStatus;
use Carbon\CarbonImmutable;

final readonly class Period
{
    public function __construct(
        public CarbonImmutable $start,
        public CarbonImmutable $end,
        public GoalPeriod $period,
        public Goal $goal,
        public float $target,
        public float $value,
        public PeriodStatus $status,
    ) {}

    public function contains(CarbonImmutable $day): bool
    {
        return $day->betweenIncluded($this->start, $this->end);
    }

    public function isMet(): bool
    {
        return $this->status === PeriodStatus::Met;
    }
}
