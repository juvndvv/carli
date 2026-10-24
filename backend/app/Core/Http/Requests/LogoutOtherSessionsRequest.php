<?php

namespace App\Core\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class LogoutOtherSessionsRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'password' => ['required', 'string', 'current_password:web'],
        ];
    }
}
