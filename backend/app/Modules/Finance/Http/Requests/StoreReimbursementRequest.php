<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreReimbursementRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'expense_id' => $this->ownedId('transactions', required: true),
            'contact_id' => $this->ownedId('contacts', required: true),
            'income_ids' => ['required', 'array', 'min:1', 'max:20'],
            'income_ids.*' => ['required', 'distinct', 'uuid'],
        ];
    }
}
