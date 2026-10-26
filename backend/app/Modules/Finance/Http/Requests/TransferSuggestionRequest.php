<?php

namespace App\Modules\Finance\Http\Requests;

final class TransferSuggestionRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'outgoing_transaction_id' => $this->ownedId('transactions', required: true),
            'incoming_transaction_id' => [...$this->ownedId('transactions', required: true), 'different:outgoing_transaction_id'],
        ];
    }
}
