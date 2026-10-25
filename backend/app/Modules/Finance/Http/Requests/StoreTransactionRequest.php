<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\ShareMode;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use Illuminate\Validation\Rule;

class StoreTransactionRequest extends FinanceRequest
{
    protected const string CATEGORY_REQUIRED = 'Elige una categoría.';

    protected bool $partial = false;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->partial ? 'sometimes' : 'required';

        return [
            'account_id' => [$required, 'bail', 'uuid', $this->owned('accounts')],
            'kind' => [$required, Rule::in(['expense', 'income', 'adjustment'])],
            'amount_cents' => [$required, 'integer', 'not_in:0', 'between:-100000000000,100000000000'],
            'date' => [$required, 'date_format:Y-m-d'],
            'category_id' => $this->partial
                ? ['sometimes', ...$this->ownedId('categories')]
                : [Rule::requiredIf(fn () => $this->requiresCategory($this->input('kind'), $this->input('splits'), $this->input('debt_id'))), ...$this->ownedId('categories')],
            'source' => ['sometimes', Rule::in([TransactionSource::Manual->value])],
            'payee' => ['sometimes', 'nullable', 'string', 'max:160'],
            'description' => ['sometimes', 'nullable', 'string', 'max:255'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'status' => ['sometimes', Rule::enum(TransactionStatus::class)],
            'debt_id' => ['sometimes', ...$this->ownedId('debts')],
            'tags' => ['sometimes', 'array', 'max:20'],
            'tags.*' => ['string', 'max:64'],
            'splits' => ['sometimes', 'nullable', 'array'],
            'splits.*.category_id' => ['required', 'bail', 'uuid', $this->owned('categories')],
            'splits.*.amount_cents' => ['required', 'integer', 'not_in:0'],
            'shares' => ['sometimes', 'nullable', 'array'],
            'shares.mode' => ['required_with:shares', Rule::enum(ShareMode::class)],
            'shares.include_self' => ['sometimes', 'boolean'],
            'shares.items' => ['required_with:shares', 'array'],
            'shares.items.*.contact_id' => ['required', 'bail', 'uuid', $this->owned('contacts')],
            'shares.items.*.percentage' => ['nullable', 'numeric', 'gt:0', 'max:100'],
            'shares.items.*.amount_cents' => ['nullable', 'integer', 'min:1'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return ['category_id.required' => self::CATEGORY_REQUIRED];
    }

    protected function requiresCategory(mixed $kind, mixed $splits, mixed $debtId): bool
    {
        return in_array($kind, [TransactionKind::Expense->value, TransactionKind::Income->value], true)
            && (! is_array($splits) || $splits === [])
            && ($debtId === null || $debtId === '');
    }

    /**
     * @return array<string, mixed>
     */
    public function payload(): array
    {
        $data = $this->validated();

        if (array_key_exists('shares', $data) && is_array($data['shares'])) {
            $data['shares']['items'] = array_values(array_map(fn (array $item) => [
                'contact_id' => (string) $item['contact_id'],
                'percentage' => isset($item['percentage']) ? (string) $item['percentage'] : null,
                'amount_cents' => isset($item['amount_cents']) ? (int) $item['amount_cents'] : null,
            ], $data['shares']['items']));
        }

        return $data;
    }
}
