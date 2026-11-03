<?php

namespace App\Modules\Calendar\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class UpdateGoogleCalendarRequest extends FormRequest
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
            'selected' => ['required', 'boolean'],
        ];
    }
}
