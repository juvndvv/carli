<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\AccountType;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

final class LinkBankAccountsRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'accounts' => ['required', 'array', 'min:1', 'max:50'],
            'accounts.*.external_account_uid' => ['required', 'string', 'max:255', 'distinct'],
            'accounts.*.account_id' => ['present', 'nullable', 'string', 'max:64'],
            'accounts.*.name' => ['sometimes', 'nullable', 'string', 'max:120'],
            'accounts.*.type' => ['sometimes', 'nullable', Rule::enum(AccountType::class)],
            'accounts.*.sync_from_date' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'before_or_equal:'.SpanishCalendar::today()->toDateString()],
        ];
    }

    /**
     * @return list<callable(Validator): void>
     */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                $chosen = [];

                foreach ((array) $this->input('accounts', []) as $index => $item) {
                    $accountId = is_array($item) ? ($item['account_id'] ?? null) : null;

                    if ($accountId === null || $accountId === 'new') {
                        continue;
                    }

                    if (! is_string($accountId) || ! Str::isUuid($accountId) || ! Account::query()->ownedBy($this->financeUser())->whereKey($accountId)->exists()) {
                        $validator->errors()->add("accounts.$index.account_id", 'La cuenta no existe.');

                        continue;
                    }

                    if (isset($chosen[$accountId])) {
                        $validator->errors()->add("accounts.$index.account_id", 'Cada cuenta solo se puede vincular a una cuenta del banco.');
                    }

                    $chosen[$accountId] = true;
                }
            },
        ];
    }

    /**
     * @return list<array{external_account_uid: string, account_id: string|null, name?: string|null, type?: string|null, sync_from_date?: string|null}>
     */
    public function items(): array
    {
        /** @var list<array{external_account_uid: string, account_id: string|null, name?: string|null, type?: string|null, sync_from_date?: string|null}> $items */
        $items = array_values((array) $this->validated('accounts'));

        return $items;
    }
}
