<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreDebtPaymentRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'account_id' => $this->ownedId('accounts', required: true),
            'amount_cents' => ['required', 'integer', 'not_in:0', 'between:-100000000000,100000000000'],
            'date' => ['nullable', 'date_format:Y-m-d'],
            'category_id' => $this->ownedId('categories'),
            'description' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
