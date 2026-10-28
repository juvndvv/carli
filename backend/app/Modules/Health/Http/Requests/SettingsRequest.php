<?php

namespace App\Modules\Health\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class SettingsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'height_cm' => ['sometimes', 'nullable', 'integer', 'between:100,230'],
            'birth_date' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'before:-6 years', 'after:1920-01-01'],
            'sex' => ['sometimes', 'nullable', 'in:male,female'],
            'goal_kg' => ['sometimes', 'nullable', 'numeric', 'between:30,300'],
            'reminder_enabled' => ['sometimes', 'boolean'],
            'reminder_time' => ['sometimes', 'date_format:H:i'],
            'reminder_days' => ['sometimes', 'array', 'min:1', 'max:7'],
            'reminder_days.*' => ['integer', 'between:1,7'],
        ];
    }
}
