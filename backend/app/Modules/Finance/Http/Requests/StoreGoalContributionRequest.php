<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreGoalContributionRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'amount_cents' => ['required', 'integer', 'not_in:0', 'between:-100000000000,100000000000'],
            'date' => ['nullable', 'date_format:Y-m-d'],
            'note' => ['nullable', 'string', 'max:255'],
            'transaction_id' => $this->ownedId('transactions'),
        ];
    }
}
