<?php

namespace App\Core\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdatePreferencesRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'theme' => ['sometimes', 'string', 'in:system,light,dark'],
            'sidebar_collapsed' => ['sometimes', 'boolean'],
        ];
    }
}
