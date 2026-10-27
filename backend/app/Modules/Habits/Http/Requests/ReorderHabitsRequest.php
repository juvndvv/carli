<?php

namespace App\Modules\Habits\Http\Requests;

final class ReorderHabitsRequest extends HabitsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'ids' => ['required', 'array', 'max:200'],
            'ids.*' => ['uuid'],
        ];
    }
}
