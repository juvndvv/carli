<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\AccountType;
use Illuminate\Validation\Rule;

class StoreAccountRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'type' => ['required', Rule::enum(AccountType::class)],
            'initial_balance_cents' => ['sometimes', 'integer', 'between:-100000000000,100000000000'],
            'initial_balance_date' => ['nullable', 'date_format:Y-m-d'],
            'credit_limit_cents' => ['nullable', 'integer', 'min:0'],
            'statement_day' => ['nullable', 'integer', 'between:1,31'],
            'payment_day' => ['nullable', 'integer', 'between:1,31'],
            'color' => ['nullable', 'string', 'max:32'],
            'icon' => ['nullable', 'string', 'max:64'],
            'include_in_net_worth' => ['sometimes', 'boolean'],
            'ownership_percent' => ['sometimes', 'integer', 'between:1,100'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ];
    }
}
