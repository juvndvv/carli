<?php

namespace App\Modules\Habits\Http\Requests;

final class ProgressRequest extends HabitsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'range' => ['sometimes', 'in:week,month,year'],
            'date' => ['sometimes', 'date_format:Y-m-d'],
        ];
    }
}
