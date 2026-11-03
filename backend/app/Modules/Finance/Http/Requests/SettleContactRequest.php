<?php

namespace App\Modules\Finance\Http\Requests;

final class SettleContactRequest extends FinanceRequest
{
    /**
     * Either an account to register a new income in, or incomes already there (e.g. Bizums
     * imported from the bank) that pay back the pending shares.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'account_id' => [...$this->ownedId('accounts'), 'required_without:income_ids', 'prohibits:income_ids'],
            'date' => ['nullable', 'date_format:Y-m-d'],
            'income_ids' => ['array', 'min:1', 'max:20'],
            'income_ids.*' => ['required', 'distinct', 'uuid'],
        ];
    }
}
