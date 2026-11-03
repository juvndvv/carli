<?php

namespace App\Modules\Health\Http\Requests;

use App\Models\User;
use App\Modules\Health\Models\BodySite;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

final class RecordBodyRequest extends FormRequest
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
        $user = $this->user();
        $userId = $user instanceof User ? $user->id : null;

        return [
            'measured_at' => ['nullable', 'date', 'before_or_equal:now'],
            'values' => ['required', 'array', 'min:1', 'max:50'],
            'values.*.site_id' => ['required', 'bail', 'uuid', 'distinct',
                Rule::exists(BodySite::class, 'id')->where('user_id', $userId)],
            'values.*.value_cm' => ['required', 'numeric', 'gt:0', 'lt:400'],
        ];
    }
}
