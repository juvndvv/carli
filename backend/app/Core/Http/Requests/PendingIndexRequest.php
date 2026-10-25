<?php

namespace App\Core\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class PendingIndexRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'module' => ['nullable', 'string', 'max:64'],
            'type' => ['nullable', 'string', 'max:64'],
            'cursor' => ['nullable', 'string', 'max:2048'],
        ];
    }

    public function filter(string $key): ?string
    {
        $value = $this->validated($key);

        return is_string($value) && $value !== '' ? $value : null;
    }
}
