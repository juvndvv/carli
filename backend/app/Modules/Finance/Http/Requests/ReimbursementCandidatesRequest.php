<?php

namespace App\Modules\Finance\Http\Requests;

final class ReimbursementCandidatesRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'expense_id' => [...$this->ownedId('transactions'), 'prohibits:income_id,contact_id'],
            'income_id' => [...$this->ownedId('transactions'), 'prohibits:contact_id'],
            'contact_id' => $this->ownedId('contacts'),
        ];
    }
}
