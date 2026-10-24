<?php

namespace App\Modules\Finance\Http\Requests;

final class CopyBudgetsRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'from_period_id' => $this->ownedId('periods', required: true),
            'to_period_id' => [...$this->ownedId('periods', required: true), 'different:from_period_id'],
        ];
    }
}
