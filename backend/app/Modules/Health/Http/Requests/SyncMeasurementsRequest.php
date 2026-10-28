<?php

namespace App\Modules\Health\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class SyncMeasurementsRequest extends FormRequest
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
            'readings' => ['required', 'array', 'min:1', 'max:200'],
            'readings.*.measured_at' => ['required', 'date'],
            'readings.*.weight_kg' => ['required', 'numeric', 'gt:2', 'lt:400'],
            'readings.*.stored' => ['sometimes', 'boolean'],
            'readings.*.impedances' => ['nullable', 'array', 'max:32'],
            'readings.*.impedances.*' => ['integer', 'between:0,65535'],
            'readings.*.frames' => ['nullable', 'string', 'max:2000'],
            'readings.*.device' => ['nullable', 'string', 'max:100'],
            'readings.*.firmware' => ['nullable', 'string', 'max:100'],
            'readings.*.metrics' => ['nullable', 'array'],
            'readings.*.metrics.bmi' => ['nullable', 'numeric', 'between:5,99.9'],
            'readings.*.metrics.fat_percent' => ['nullable', 'numeric', 'between:0,99.9'],
            'readings.*.metrics.muscle_percent' => ['nullable', 'numeric', 'between:0,99.9'],
            'readings.*.metrics.water_percent' => ['nullable', 'numeric', 'between:0,99.9'],
            'readings.*.metrics.visceral_or_bone' => ['nullable', 'integer', 'between:0,255'],
            'readings.*.metrics.basal_kcal' => ['nullable', 'integer', 'between:0,10000'],
            'readings.*.metrics_frame' => ['nullable', 'string', 'max:200'],
        ];
    }
}
