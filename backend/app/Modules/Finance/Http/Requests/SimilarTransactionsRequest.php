<?php

namespace App\Modules\Finance\Http\Requests;

final class SimilarTransactionsRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'pattern' => ['sometimes', 'nullable', 'string', 'min:2', 'max:120'],
        ];
    }
}
