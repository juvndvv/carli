<?php

namespace App\Modules\Finance\Http\Requests;

final class ConfirmRecurringRuleRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'amount_cents' => ['nullable', 'integer', 'not_in:0', 'between:-100000000000,100000000000'],
            'date' => ['nullable', 'date_format:Y-m-d'],
            'update_rule_amount' => ['nullable', 'boolean'],
        ];
    }
}
