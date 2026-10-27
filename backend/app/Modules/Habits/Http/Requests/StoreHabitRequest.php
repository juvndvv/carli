<?php

namespace App\Modules\Habits\Http\Requests;

use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Domain\Support\HabitIcons;
use App\Modules\Habits\Models\Habit;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

final class StoreHabitRequest extends HabitsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('POST');

        return [
            'name' => [$creating ? 'required' : 'sometimes', 'string', 'max:120'],
            'icon' => [$creating ? 'required' : 'sometimes', Rule::in(HabitIcons::ALL)],
            'kind' => $creating ? ['required', Rule::enum(HabitKind::class)] : ['prohibited'],
            'unit' => ['sometimes', 'nullable', 'string', 'max:30'],
            'show_in_tasks' => ['sometimes', 'boolean'],
            'start_date' => ['sometimes', 'date_format:Y-m-d', 'before_or_equal:'.HabitCalendar::today()->addYear()->toDateString()],
            'preferred_time' => ['sometimes', 'nullable', 'date_format:H:i'],
            'period' => [$creating ? 'required' : 'sometimes', Rule::enum(GoalPeriod::class)],
            'target' => ['sometimes', 'numeric', 'min:0', 'max:100000'],
            'days_of_week' => ['sometimes', 'nullable', 'array', 'max:7'],
            'days_of_week.*' => ['integer', 'between:1,7', 'distinct'],
        ];
    }

    /**
     * @return list<callable(Validator): void>
     */
    public function after(): array
    {
        return [function (Validator $validator): void {
            $habit = $this->route('habit');
            $kind = $habit instanceof Habit ? $habit->kind : HabitKind::tryFrom((string) $this->input('kind'));
            $period = GoalPeriod::tryFrom((string) $this->input('period', $habit instanceof Habit ? $habit->currentGoal()->period->value : ''));
            $target = $this->input('target');

            if ($kind === HabitKind::Quantity && $this->has('target') && (float) $target <= 0) {
                $validator->errors()->add('target', 'La cantidad debe ser mayor que cero.');
            }

            if ($kind === HabitKind::Quantity && ! $habit instanceof Habit && ! $this->has('target')) {
                $validator->errors()->add('target', 'Indica la cantidad objetivo.');
            }

            if ($kind === HabitKind::Check && $period === GoalPeriod::Week && $this->has('target') && ((float) $target < 1 || (float) $target > 7 || floor((float) $target) !== (float) $target)) {
                $validator->errors()->add('target', 'Indica entre 1 y 7 veces por semana.');
            }

            if ($kind === HabitKind::Check && $period === GoalPeriod::Week && ! $habit instanceof Habit && ! $this->has('target')) {
                $validator->errors()->add('target', 'Indica cuántas veces por semana.');
            }
        }];
    }
}
