<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\AccountType;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class AccountService
{
    public function __construct(private readonly TransactionService $transactions) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data): Account
    {
        $account = new Account;
        $account->user_id = $user->id;
        $account->fill($this->attributes($data));
        $account->sort_order = (int) ($data['sort_order'] ?? ((int) Account::query()->ownedBy($user)->max('sort_order') + 1));
        $account->save();

        return $this->reload($account);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Account $account, array $data): Account
    {
        $account->fill($this->attributes($data));

        if (array_key_exists('archived', $data)) {
            $account->archived_at = $data['archived'] ? ($account->archived_at ?? CarbonImmutable::now()) : null;
        }

        if ($account->type !== AccountType::CreditCard) {
            $account->credit_limit_cents = null;
            $account->statement_day = null;
            $account->payment_day = null;
        }

        $account->save();

        return $this->reload($account);
    }

    public function delete(Account $account): void
    {
        $hasMovements = Transaction::query()->withoutGlobalScopes()->withTrashed()->where('account_id', $account->id)->exists();

        if ($hasMovements) {
            throw ValidationException::withMessages(['account' => 'La cuenta tiene movimientos. Archívala en lugar de borrarla.']);
        }

        $account->delete();
    }

    /**
     * @return array{adjustment: Transaction|null, balance_cents: int, difference_cents: int}
     */
    public function reconcile(Account $account, int $actualBalanceCents, ?string $date = null): array
    {
        return DB::transaction(function () use ($account, $actualBalanceCents, $date): array {
            $locked = Account::query()->withoutGlobalScopes()->whereKey($account->id)->lockForUpdate()->firstOrFail();
            $difference = $actualBalanceCents - $locked->clearedBalanceCents();
            $adjustment = null;

            if ($difference !== 0) {
                $adjustment = $this->transactions->create($account->user_id, [
                    'account_id' => $account->id,
                    'kind' => TransactionKind::Adjustment->value,
                    'amount_cents' => $difference,
                    'date' => $date ?? SpanishCalendar::today()->toDateString(),
                    'description' => 'Ajuste de conciliación',
                    'status' => TransactionStatus::Cleared->value,
                ]);
            }

            return [
                'adjustment' => $adjustment,
                'balance_cents' => $locked->balanceCents(),
                'difference_cents' => $difference,
            ];
        });
    }

    public function reload(Account $account): Account
    {
        return Account::query()->withoutGlobalScopes()->withBalance()->with('bankConnection')->whereKey($account->id)->firstOrFail();
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data): array
    {
        return array_intersect_key($data, array_flip([
            'name', 'type', 'initial_balance_cents', 'initial_balance_date', 'credit_limit_cents',
            'statement_day', 'payment_day', 'color', 'icon', 'include_in_net_worth', 'sort_order',
        ]));
    }
}
