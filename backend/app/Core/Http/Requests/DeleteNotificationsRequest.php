<?php

namespace App\Core\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class DeleteNotificationsRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'all' => ['sometimes', 'boolean'],
            'read' => ['sometimes', 'boolean'],
            'ids' => ['required_without_all:all,read', 'array', 'max:500'],
            'ids.*' => ['uuid'],
        ];
    }
}
