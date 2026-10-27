<?php

namespace App\Modules\Habits\Http\Requests;

use App\Modules\Habits\Domain\Support\HabitIcons;
use Illuminate\Validation\Rule;

final class ConvertTemplateRequest extends HabitsRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'template_id' => ['required', 'uuid'],
            'name' => ['sometimes', 'nullable', 'string', 'max:120'],
            'icon' => ['sometimes', 'nullable', Rule::in(HabitIcons::ALL)],
            'show_in_tasks' => ['sometimes', 'boolean'],
        ];
    }
}
