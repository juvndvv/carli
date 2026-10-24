<?php

namespace App\Modules\Finance\Http\Requests;

final class SettleContactRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'account_id' => $this->ownedId('accounts', required: true),
            'date' => ['nullable', 'date_format:Y-m-d'],
        ];
    }
}
