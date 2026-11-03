<?php

namespace App\Modules\Health\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class BodyOverviewRequest extends FormRequest
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
            // "first" compares with each site's first measurement; a day, with the last one on or before it.
            'compare' => ['nullable', 'string', function (string $attribute, mixed $value, \Closure $fail): void {
                if ($value !== 'first' && ! (is_string($value) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $value) === 1 && strtotime($value) !== false)) {
                    $fail('Compara con "first" o con una fecha AAAA-MM-DD.');
                }
            }],
            'from' => ['nullable', 'date_format:Y-m-d'],
            'archived' => ['nullable', 'boolean'],
        ];
    }
}
