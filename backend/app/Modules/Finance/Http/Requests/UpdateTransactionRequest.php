<?php

namespace App\Modules\Finance\Http\Requests;

use Illuminate\Validation\Rule;

final class UpdateTransactionRequest extends StoreTransactionRequest
{
    protected bool $partial = true;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            ...parent::rules(),
            'kind' => ['sometimes', Rule::in(['expense', 'income', 'adjustment', 'transfer'])],
        ];
    }
}
