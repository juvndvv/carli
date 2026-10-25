<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

final class UpdateTransactionRequest extends StoreTransactionRequest
{
    private const string BANK_LOCKED = 'Este dato viene del banco y no se puede cambiar.';

    protected bool $partial = true;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            ...parent::rules(),
            'kind' => ['sometimes', Rule::in(['expense', 'income', 'adjustment', 'transfer'])],
        ];
    }

    /**
     * @return list<callable(Validator): void>
     */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                $transaction = $this->route('transaction');

                if (! $transaction instanceof Transaction || $transaction->source !== TransactionSource::Bank) {
                    return;
                }

                $current = [
                    'account_id' => $transaction->account_id,
                    'kind' => $transaction->kind->value,
                    'amount_cents' => $transaction->amount_cents,
                    'date' => $transaction->date->toDateString(),
                ];

                foreach ($current as $field => $value) {
                    if ($this->has($field) && (string) $this->input($field) !== (string) $value) {
                        $validator->errors()->add($field, self::BANK_LOCKED);
                    }
                }
            },
            function (Validator $validator): void {
                $transaction = $this->route('transaction');

                if (! $transaction instanceof Transaction || ! $this->has('category_id') || $this->input('category_id') !== null) {
                    return;
                }

                if ($transaction->source === TransactionSource::Bank || $transaction->settledShares()->exists()) {
                    return;
                }

                $splits = $this->has('splits') ? $this->input('splits') : $transaction->splits()->pluck('id')->all();
                $debtId = $this->has('debt_id') ? $this->input('debt_id') : $transaction->debt_id;

                if ($this->requiresCategory($this->input('kind', $transaction->kind->value), $splits, $debtId)) {
                    $validator->errors()->add('category_id', self::CATEGORY_REQUIRED);
                }
            },
        ];
    }
}
