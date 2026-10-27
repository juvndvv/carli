<?php

namespace App\Modules\Habits\Http\Resources;

use App\Modules\Habits\Domain\Evaluation\Goal;
use App\Modules\Habits\Domain\Support\GoalDescriber;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Models\Habit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Habit
 */
final class HabitResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(?Request $request = null): array
    {
        /** @var Habit $habit */
        $habit = $this->resource;
        $habit->loadMissing('goals');
        $goal = Goal::fromModel($habit->currentGoal());

        return [
            'id' => $habit->id,
            'name' => $habit->name,
            'icon' => $habit->icon,
            'kind' => $habit->kind->value,
            'unit' => $habit->unit,
            'show_in_tasks' => $habit->show_in_tasks,
            'sort' => $habit->sort,
            'start_date' => $habit->start_date->toDateString(),
            'preferred_time' => HabitCalendar::time($habit->preferred_time),
            'status' => match (true) {
                $habit->archived_at !== null => 'archived',
                $habit->paused_at !== null => 'paused',
                default => 'active',
            },
            'paused_at' => $habit->paused_at?->toIso8601String(),
            'archived_at' => $habit->archived_at?->toIso8601String(),
            'converted_from_template_id' => $habit->converted_from_template_id,
            'goal' => [
                'period' => $goal->period->value,
                'target' => $goal->target,
                'days_of_week' => $goal->daysOfWeek,
                'valid_from' => $goal->validFrom->toDateString(),
            ],
            'goal_text' => GoalDescriber::describe($habit->kind, $habit->unit, $goal),
        ];
    }
}
