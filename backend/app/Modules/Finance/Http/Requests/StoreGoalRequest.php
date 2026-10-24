<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreGoalRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name' => [$required, 'string', 'max:120'],
            'target_cents' => [$required, 'integer', 'min:1', 'max:100000000000'],
            'target_date' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'account_id' => ['sometimes', ...$this->ownedId('accounts')],
            'icon' => ['sometimes', 'nullable', 'string', 'max:64'],
            'color' => ['sometimes', 'nullable', 'string', 'max:32'],
        ];
    }
}
