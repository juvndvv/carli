<?php

namespace App\Modules\Finance\Http\Requests;

use Illuminate\Validation\Rule;

final class PayeeSuggestRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'q' => ['nullable', 'string', 'max:120'],
            'kind' => ['nullable', Rule::in(['expense', 'income'])],
            'limit' => ['nullable', 'integer', 'between:1,25'],
        ];
    }
}
