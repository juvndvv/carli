<?php

namespace App\Modules\Finance\Http\Requests;

final class LinkTransferRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'account_id' => $this->ownedId('accounts', required: true),
        ];
    }
}
