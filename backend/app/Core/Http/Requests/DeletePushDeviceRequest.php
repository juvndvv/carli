<?php

namespace App\Core\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class DeletePushDeviceRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'token' => ['required', 'string', 'max:200'],
        ];
    }
}
