<?php

namespace App\Modules\Habits\Domain\Evaluation;

use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Models\Habit;
use App\Modules\Habits\Models\HabitBreak;
use App\Modules\Habits\Models\HabitEntry;
use App\Modules\Habits\Models\HabitGoal;
use Carbon\CarbonImmutable;
use InvalidArgumentException;

final readonly class Timeline
{
    /**
     * @param  non-empty-list<Goal>  $goals
     * @param  array<string, float>  $values
     * @param  list<array{0: CarbonImmutable, 1: CarbonImmutable}>  $breaks
     */
    public function __construct(
        public HabitKind $kind,
        public CarbonImmutable $start,
        public ?CarbonImmutable $stop,
        public array $goals,
        public array $values = [],
        public array $breaks = [],
    ) {}

    /**
     * @param  iterable<HabitBreak>  $globalBreaks
     */
    public static function fromHabit(Habit $habit, iterable $globalBreaks = []): self
    {
        $goals = array_values($habit->goals->sortBy(fn (HabitGoal $goal) => $goal->valid_from->toDateString())->map(Goal::fromModel(...))->all());

        if ($goals === []) {
            throw new InvalidArgumentException("Habit [{$habit->id}] has no goal.");
        }

        $values = [];
        foreach ($habit->entries as $entry) {
            /** @var HabitEntry $entry */
            $values[$entry->date->toDateString()] = $entry->value;
        }

        $breaks = [];
        foreach ([...$habit->breaks, ...$globalBreaks] as $break) {
            /** @var HabitBreak $break */
            $breaks[] = [$break->from_date, $break->to_date];
        }

        return new self($habit->kind, $habit->start_date, $habit->stoppedOn(), $goals, $values, $breaks);
    }

    public function goalOn(CarbonImmutable $day): Goal
    {
        $current = $this->goals[0];

        foreach ($this->goals as $goal) {
            if ($goal->validFrom->gt($day)) {
                break;
            }

            $current = $goal;
        }

        return $current;
    }

    public function currentGoal(): Goal
    {
        return $this->goals[array_key_last($this->goals)];
    }

    public function valueOn(CarbonImmutable $day): float
    {
        return $this->values[$day->toDateString()] ?? 0.0;
    }

    public function isOnBreak(CarbonImmutable $day): bool
    {
        foreach ($this->breaks as [$from, $to]) {
            if ($day->betweenIncluded($from, $to)) {
                return true;
            }
        }

        return false;
    }

    public function isTracked(CarbonImmutable $day): bool
    {
        return $day->gte($this->start) && ($this->stop === null || $day->lt($this->stop));
    }

    public function lastTrackedDay(CarbonImmutable $today): CarbonImmutable
    {
        return $this->stop === null ? $today : $today->min($this->stop->subDay());
    }
}
