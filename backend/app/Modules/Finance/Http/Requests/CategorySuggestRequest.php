<?php

namespace App\Modules\Finance\Http\Requests;

use Illuminate\Validation\Rule;

final class CategorySuggestRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'payee' => ['nullable', 'string', 'max:120', 'required_without:description'],
            'description' => ['nullable', 'string', 'max:255', 'required_without:payee'],
            'kind' => ['nullable', Rule::in(['expense', 'income'])],
        ];
    }
}
