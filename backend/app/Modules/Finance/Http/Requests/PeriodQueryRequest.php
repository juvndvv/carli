<?php

namespace App\Modules\Finance\Http\Requests;

final class PeriodQueryRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'period_id' => $this->ownedId('periods'),
        ];
    }
}
