<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\TransactionStatus;
use Illuminate\Validation\Rule;

final class StoreTransferRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'from_account_id' => ['required', 'bail', 'uuid', $this->owned('accounts')],
            'to_account_id' => ['required', 'bail', 'uuid', 'different:from_account_id', $this->owned('accounts')],
            'amount_cents' => ['required', 'integer', 'min:1', 'max:100000000000'],
            'date' => ['required', 'date_format:Y-m-d'],
            'description' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'status' => ['nullable', Rule::enum(TransactionStatus::class)],
            'tags' => ['nullable', 'array'],
            'tags.*' => ['string', 'max:64'],
        ];
    }
}
