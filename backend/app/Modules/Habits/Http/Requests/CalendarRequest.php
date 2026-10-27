<?php

namespace App\Modules\Habits\Http\Requests;

final class CalendarRequest extends HabitsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'month' => ['sometimes', 'date_format:Y-m'],
        ];
    }
}
