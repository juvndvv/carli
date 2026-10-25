<?php

namespace App\Modules\Finance\BankSync\Services;

use App\Models\User;
use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Data\BankAmount;
use App\Modules\Finance\BankSync\Data\PsuContext;
use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use App\Modules\Finance\Domain\Enums\BankConnectionStatus;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\CategoryRuleService;
use App\Modules\Finance\Domain\Services\GoalService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use App\Modules\Finance\Models\CategoryRule;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\BankSyncFailed;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Throwable;

final class BankSyncService
{
    public const int OVERLAP_DAYS = 5;

    private const int PAYEE_MAX = 160;

    private const int DESCRIPTION_MAX = 255;

    public function __construct(
        private readonly BankDataProvider $provider,
        private readonly CategoryRuleService $rules,
        private readonly BudgetService $budgets,
        private readonly GoalService $goals,
        private readonly PeriodService $periods,
    ) {}

    /**
     * @return array{imported: int, accounts: int}
     */
    public function sync(BankConnection $connection, ?PsuContext $psu = null): array
    {
        if (! $connection->status->isSyncable()) {
            return ['imported' => 0, 'accounts' => 0];
        }

        if ($connection->valid_until->isPast()) {
            $connection->forceFill(['status' => BankConnectionStatus::Expired])->save();

            return ['imported' => 0, 'accounts' => 0];
        }

        try {
            $result = $this->syncAccounts($connection, $psu);
        } catch (BankProviderException $exception) {
            $this->recordFailure($connection, $exception->getMessage());

            return ['imported' => 0, 'accounts' => 0];
        } catch (Throwable $exception) {
            $this->recordFailure($connection, 'Error inesperado al sincronizar.');

            throw $exception;
        }

        $connection->forceFill([
            'status' => BankConnectionStatus::Active,
            'last_synced_at' => CarbonImmutable::now(),
            'last_error' => null,
        ])->save();

        return $result;
    }

    /**
     * @return array{imported: int, accounts: int}
     */
    private function syncAccounts(BankConnection $connection, ?PsuContext $psu): array
    {
        $accounts = Account::query()->ownedBy($connection->user_id)
            ->where('bank_connection_id', $connection->id)
            ->whereNotNull('external_account_uid')
            ->whereNotNull('sync_from_date')
            ->whereNull('archived_at')
            ->get();

        $rules = $this->rules->rulesFor($connection->user_id);
        $imported = new Collection;

        foreach ($accounts as $account) {
            $imported = $imported->merge($this->syncAccount($account, $rules, $psu));
        }

        $this->evaluateAlerts($connection->user_id, $imported);

        return ['imported' => $imported->count(), 'accounts' => $accounts->count()];
    }

    /**
     * @param  Collection<int, CategoryRule>  $rules
     * @return Collection<int, Transaction>
     */
    public function syncAccount(Account $account, Collection $rules, ?PsuContext $psu = null): Collection
    {
        $uid = (string) $account->external_account_uid;
        $syncFrom = $account->sync_from_date ?? SpanishCalendar::today();
        $today = SpanishCalendar::today();
        $from = $this->windowStart($account, $syncFrom);
        $imported = new Collection;

        if ($from->lessThanOrEqualTo($today)) {
            $rows = $this->map($this->provider->fetchTransactions($uid, $from, $today, $psu), $syncFrom);
            $imported = $this->store($account, $rows, $rules);
        }

        $balance = $this->provider->fetchBalance($uid, $psu);
        if ($balance !== null) {
            $account->forceFill([
                'bank_balance_cents' => $balance->amountCents,
                'bank_balance_at' => CarbonImmutable::now(),
            ])->save();
        }

        return $imported;
    }

    public function windowStart(Account $account, CarbonImmutable $syncFrom): CarbonImmutable
    {
        $lastBooked = Transaction::query()->withoutGlobalScopes()->withTrashed()
            ->where('account_id', $account->id)
            ->where('source', TransactionSource::Bank->value)
            ->whereNotNull('external_id')
            ->max('date');

        if (! is_string($lastBooked)) {
            return $syncFrom;
        }

        $overlap = SpanishCalendar::date($lastBooked)->subDays(self::OVERLAP_DAYS);

        return $overlap->greaterThan($syncFrom) ? $overlap : $syncFrom;
    }

    /**
     * @param  list<array<string, mixed>>  $transactions
     * @return list<array{external_id: string, kind: TransactionKind, amount_cents: int, date: CarbonImmutable, payee: string|null, description: string|null, raw: array<string, mixed>}>
     */
    public function map(array $transactions, CarbonImmutable $syncFrom): array
    {
        $rows = [];
        $seen = [];
        $occurrences = [];

        foreach ($transactions as $transaction) {
            if (($transaction['status'] ?? null) !== 'BOOK') {
                continue;
            }

            $date = $this->bookingDate($transaction);
            $amount = $this->signedAmount($transaction);

            if ($date === null || $amount === null || $amount === 0 || $date->lessThan($syncFrom)) {
                continue;
            }

            $isDebit = $amount < 0;
            $counterparty = $isDebit ? ($transaction['creditor'] ?? null) : ($transaction['debtor'] ?? null);
            $payee = $this->text(is_array($counterparty) ? ($counterparty['name'] ?? null) : null, self::PAYEE_MAX);
            $description = $this->text($this->concept($transaction), self::DESCRIPTION_MAX);

            $externalId = $this->externalId($transaction);
            if ($externalId === null) {
                $base = implode('|', [$date->toDateString(), $amount, $description ?? $payee ?? '']);
                $index = $occurrences[$base] = ($occurrences[$base] ?? -1) + 1;
                $externalId = hash('sha256', $base.'|'.$index);
            }

            if (isset($seen[$externalId])) {
                continue;
            }
            $seen[$externalId] = true;

            $rows[] = [
                'external_id' => $externalId,
                'kind' => $isDebit ? TransactionKind::Expense : TransactionKind::Income,
                'amount_cents' => $amount,
                'date' => $date,
                'payee' => $payee,
                'description' => $description,
                'raw' => $transaction,
            ];
        }

        return $rows;
    }

    /**
     * @param  list<array{external_id: string, kind: TransactionKind, amount_cents: int, date: CarbonImmutable, payee: string|null, description: string|null, raw: array<string, mixed>}>  $rows
     * @param  Collection<int, CategoryRule>  $rules
     * @return Collection<int, Transaction>
     */
    private function store(Account $account, array $rows, Collection $rules): Collection
    {
        if ($rows === []) {
            return new Collection;
        }

        return DB::transaction(function () use ($account, $rows, $rules): Collection {
            Account::query()->withoutGlobalScopes()->whereKey($account->id)->lockForUpdate()->first();

            $known = Transaction::query()->withoutGlobalScopes()->withTrashed()
                ->where('account_id', $account->id)
                ->whereIn('external_id', array_column($rows, 'external_id'))
                ->pluck('external_id')
                ->flip();

            $created = new Collection;

            foreach ($rows as $row) {
                if ($known->has($row['external_id'])) {
                    continue;
                }

                $rule = $this->rules->match($rules, $row['kind'], $row['payee'], $row['description']);

                $transaction = new Transaction;
                $transaction->user_id = $account->user_id;
                $transaction->account_id = $account->id;
                $transaction->kind = $row['kind'];
                $transaction->amount_cents = $row['amount_cents'];
                $transaction->date = $row['date'];
                $transaction->payee = $row['payee'];
                $transaction->description = $row['description'];
                $transaction->status = TransactionStatus::Cleared;
                $transaction->source = TransactionSource::Bank;
                $transaction->external_id = $row['external_id'];
                $transaction->raw = $row['raw'];
                $transaction->category_id = $rule !== null && ! $rule->category->opens_period ? $rule->category_id : null;
                $transaction->save();

                $created->push($transaction);
            }

            return $created;
        });
    }

    /**
     * @param  Collection<int, Transaction>  $imported
     */
    private function evaluateAlerts(string $userId, Collection $imported): void
    {
        $representatives = [];

        foreach ($imported as $transaction) {
            if ($transaction->kind !== TransactionKind::Expense || $transaction->category_id === null) {
                continue;
            }

            $period = $this->periods->forDate($userId, $transaction->date);
            if ($period === null) {
                continue;
            }

            $representatives[$period->id.'|'.$transaction->category_id] = $transaction;
        }

        foreach ($representatives as $transaction) {
            $this->budgets->checkThresholds($transaction);
        }

        foreach ($imported->pluck('account_id')->unique() as $accountId) {
            $this->goals->checkGoalsForAccount($userId, (string) $accountId);
        }
    }

    private function recordFailure(BankConnection $connection, string $message): void
    {
        $wasFailing = $connection->status === BankConnectionStatus::Error;

        $connection->forceFill([
            'status' => BankConnectionStatus::Error,
            'last_error' => Str::limit($message, 500),
        ])->save();

        if (! $wasFailing) {
            User::query()->find($connection->user_id)?->notify(new BankSyncFailed($connection->id, $connection->aspsp_name, $message));
        }
    }

    /**
     * @param  array<string, mixed>  $transaction
     */
    private function bookingDate(array $transaction): ?CarbonImmutable
    {
        foreach (['booking_date', 'value_date', 'transaction_date'] as $key) {
            $value = $transaction[$key] ?? null;
            if (is_string($value) && preg_match('/^\d{4}-\d{2}-\d{2}/', $value) === 1) {
                return SpanishCalendar::date($value);
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $transaction
     */
    private function signedAmount(array $transaction): ?int
    {
        $money = $transaction['transaction_amount'] ?? null;
        $amount = is_array($money) ? ($money['amount'] ?? null) : null;

        if (! is_string($amount) && ! is_int($amount) && ! is_float($amount)) {
            return null;
        }

        try {
            $cents = abs(BankAmount::toCents($amount));
        } catch (InvalidArgumentException) {
            return null;
        }

        return ($transaction['credit_debit_indicator'] ?? null) === 'DBIT' ? -$cents : $cents;
    }

    /**
     * @param  array<string, mixed>  $transaction
     */
    private function externalId(array $transaction): ?string
    {
        foreach (['entry_reference', 'transaction_id'] as $key) {
            $value = $transaction[$key] ?? null;
            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $transaction
     */
    private function concept(array $transaction): ?string
    {
        $remittance = $transaction['remittance_information'] ?? null;
        $lines = is_array($remittance) ? array_filter($remittance, fn (mixed $line) => is_string($line) && trim($line) !== '') : [];

        if ($lines !== []) {
            return implode(' ', array_map('trim', $lines));
        }

        $code = $transaction['bank_transaction_code'] ?? null;
        $description = is_array($code) ? ($code['description'] ?? null) : null;

        return is_string($description) ? $description : null;
    }

    private function text(mixed $value, int $max): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $clean = trim(preg_replace('/\s+/', ' ', $value) ?? '');

        return $clean === '' ? null : Str::limit($clean, $max, '');
    }
}
