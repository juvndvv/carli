<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\DebtDirection;
use App\Modules\Finance\Domain\Enums\RecurringMode;
use Illuminate\Validation\Rule;

final class StoreDebtRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name' => [$required, 'string', 'max:120'],
            'direction' => [$required, Rule::enum(DebtDirection::class)],
            'contact_id' => ['sometimes', ...$this->ownedId('contacts')],
            'principal_cents' => [$required, 'integer', 'min:1', 'max:100000000000'],
            'start_date' => [$required, 'date_format:Y-m-d'],
            'due_date' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'closed' => ['sometimes', 'boolean'],
            'plan' => ['sometimes', 'nullable', 'array'],
            'plan.account_id' => ['required_with:plan', 'bail', 'uuid', $this->owned('accounts')],
            'plan.installment_cents' => ['required_with:plan', 'integer', 'min:1'],
            'plan.installments_count' => ['required_with:plan', 'integer', 'between:1,600'],
            'plan.first_payment_date' => ['required_with:plan', 'date_format:Y-m-d'],
            'plan.payment_day' => ['nullable', 'integer', 'between:1,31'],
            'plan.category_id' => ['nullable', 'bail', 'uuid', $this->owned('categories')],
            'plan.mode' => ['nullable', Rule::enum(RecurringMode::class)],
        ];
    }
}
