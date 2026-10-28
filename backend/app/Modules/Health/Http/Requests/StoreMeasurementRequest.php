<?php

namespace App\Modules\Health\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class StoreMeasurementRequest extends FormRequest
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
            'weight_kg' => ['required', 'numeric', 'gt:0', 'lt:400'],
            'measured_at' => ['nullable', 'date', 'before_or_equal:now'],
            'fat_percent' => ['nullable', 'numeric', 'between:1,80'],
            'muscle_percent' => ['nullable', 'numeric', 'between:1,90'],
            'water_percent' => ['nullable', 'numeric', 'between:1,90'],
        ];
    }
}
