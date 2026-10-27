<?php

namespace App\Modules\Habits\Http\Requests;

use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Models\Habit;
use Carbon\CarbonImmutable;
use Illuminate\Validation\Validator;
use InvalidArgumentException;

final class EntryRequest extends HabitsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'value' => [$this->isMethod('DELETE') ? 'prohibited' : 'required', 'numeric', 'min:0', 'max:100000'],
            'note' => ['sometimes', 'nullable', 'string', 'max:280'],
        ];
    }

    public function day(): CarbonImmutable
    {
        try {
            return HabitCalendar::date((string) $this->route('date'));
        } catch (InvalidArgumentException) {
            abort(404);
        }
    }

    /**
     * @return list<callable(Validator): void>
     */
    public function after(): array
    {
        return [function (Validator $validator): void {
            $habit = $this->route('habit');

            if (! $habit instanceof Habit) {
                return;
            }

            $day = $this->day();

            if ($day->gt(HabitCalendar::today())) {
                $validator->errors()->add('date', 'No se puede registrar un día futuro.');
            }

            if ($day->lt($habit->start_date)) {
                $validator->errors()->add('date', 'El hábito todavía no había empezado ese día.');
            }

            if ($habit->kind === HabitKind::Check && $this->has('value') && ! in_array((float) $this->input('value'), [0.0, 1.0], true)) {
                $validator->errors()->add('value', 'Un hábito de sí o no solo admite 0 o 1.');
            }
        }];
    }
}
