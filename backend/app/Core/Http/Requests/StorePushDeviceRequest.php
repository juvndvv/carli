<?php

namespace App\Core\Http\Requests;

use App\Core\Push\ApnsEnvironment;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePushDeviceRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'token' => ['required', 'string', 'regex:/^[0-9a-fA-F]{64,200}$/'],
            'environment' => ['required', Rule::enum(ApnsEnvironment::class)],
        ];
    }
}
