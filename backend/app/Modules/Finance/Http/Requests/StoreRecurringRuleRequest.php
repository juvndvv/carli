<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\RecurrenceFrequency;
use App\Modules\Finance\Domain\Enums\RecurringMode;
use Illuminate\Validation\Rule;

class StoreRecurringRuleRequest extends FinanceRequest
{
    protected bool $partial = false;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->partial ? 'sometimes' : 'required';

        return [
            'account_id' => [$required, 'bail', 'uuid', $this->owned('accounts')],
            'category_id' => ['sometimes', ...$this->ownedId('categories')],
            'kind' => [$required, Rule::in(['expense', 'income'])],
            'amount_cents' => [$required, 'integer', 'not_in:0', 'between:-100000000000,100000000000'],
            'payee' => ['sometimes', 'nullable', 'string', 'max:160'],
            'description' => ['sometimes', 'nullable', 'string', 'max:255'],
            'frequency' => [$required, Rule::enum(RecurrenceFrequency::class)],
            'interval' => ['sometimes', 'integer', 'between:1,365'],
            'day_of_month' => ['sometimes', 'nullable', 'integer', 'between:1,31'],
            'start_date' => [$required, 'date_format:Y-m-d'],
            'end_date' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'mode' => ['sometimes', Rule::enum(RecurringMode::class)],
            'remind_days_before' => ['sometimes', 'integer', 'between:0,30'],
            'is_subscription' => ['sometimes', 'boolean'],
            'cancelled' => ['sometimes', 'boolean'],
        ];
    }
}
