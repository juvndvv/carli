<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\TransactionStatus;
use Illuminate\Validation\Rule;

final class BulkUpdateTransactionsRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'ids' => ['required', 'array', 'min:1', 'max:500'],
            'ids.*' => ['bail', 'uuid', $this->owned('transactions')],
            'category_id' => ['sometimes', ...$this->ownedId('categories')],
            'account_id' => ['sometimes', 'bail', 'uuid', $this->owned('accounts')],
            'status' => ['sometimes', Rule::enum(TransactionStatus::class)],
            'tags' => ['sometimes', 'array'],
            'tags.*' => ['string', 'max:64'],
            'add_tags' => ['sometimes', 'array'],
            'add_tags.*' => ['string', 'max:64'],
            'remove_tags' => ['sometimes', 'array'],
            'remove_tags.*' => ['string', 'max:64'],
        ];
    }
}
