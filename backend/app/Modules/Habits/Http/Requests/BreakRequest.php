<?php

namespace App\Modules\Habits\Http\Requests;

final class BreakRequest extends HabitsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('POST');

        return [
            'habit_id' => $creating ? $this->ownedHabit() : ['prohibited'],
            'from_date' => [$creating ? 'required' : 'sometimes', 'date_format:Y-m-d'],
            'to_date' => [$creating ? 'required' : 'sometimes', 'date_format:Y-m-d', ...($this->has('from_date') ? ['after_or_equal:from_date'] : [])],
        ];
    }
}
