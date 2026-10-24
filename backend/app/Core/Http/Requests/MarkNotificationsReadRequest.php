<?php

namespace App\Core\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class MarkNotificationsReadRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'all' => ['sometimes', 'boolean'],
            'ids' => ['required_without:all', 'array', 'max:500'],
            'ids.*' => ['uuid'],
        ];
    }
}
