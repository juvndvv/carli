<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\AccountType;
use Illuminate\Validation\Rule;

final class UpdateAccountRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:120'],
            'type' => ['sometimes', Rule::enum(AccountType::class)],
            'initial_balance_cents' => ['sometimes', 'integer', 'between:-100000000000,100000000000'],
            'initial_balance_date' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'credit_limit_cents' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'statement_day' => ['sometimes', 'nullable', 'integer', 'between:1,31'],
            'payment_day' => ['sometimes', 'nullable', 'integer', 'between:1,31'],
            'color' => ['sometimes', 'nullable', 'string', 'max:32'],
            'icon' => ['sometimes', 'nullable', 'string', 'max:64'],
            'include_in_net_worth' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'archived' => ['sometimes', 'boolean'],
        ];
    }
}
