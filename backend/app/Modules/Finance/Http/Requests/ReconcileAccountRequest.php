<?php

namespace App\Modules\Finance\Http\Requests;

final class ReconcileAccountRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'actual_balance_cents' => ['required', 'integer', 'between:-100000000000,100000000000'],
            'date' => ['nullable', 'date_format:Y-m-d'],
        ];
    }
}
