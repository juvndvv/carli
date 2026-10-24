<?php

namespace App\Modules\Finance\Http\Requests;

final class UpsertBudgetsRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'period_id' => $this->ownedId('periods'),
            'budgets' => ['required', 'array'],
            'budgets.*.category_id' => ['required', 'bail', 'uuid', $this->owned('categories')],
            'budgets.*.amount_cents' => ['present', 'nullable', 'integer', 'min:0', 'max:100000000000'],
            'budgets.*.rollover' => ['sometimes', 'nullable', 'boolean'],
        ];
    }
}
