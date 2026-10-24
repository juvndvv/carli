<?php

namespace App\Core\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class DeletePushSubscriptionRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'endpoint' => ['required', 'string', 'max:2048'],
        ];
    }
}
