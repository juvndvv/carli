<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\ShareMode;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Events\PayrollRegistered;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\SharedExpenseShare;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Models\TransactionSplit;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class TransactionService
{
    public bool $periodsChanged = false;

    private const array EDITABLE = ['account_id', 'kind', 'amount_cents', 'date', 'category_id', 'payee', 'description', 'notes', 'status', 'debt_id'];

    public function __construct(
        private readonly PeriodService $periods,
        private readonly TagService $tags,
        private readonly ShareCalculator $shareCalculator,
        private readonly TransferService $transfers,
    ) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User|string $user, array $data, ?string $recurringRuleId = null, ?string $recurringDate = null): Transaction
    {
        $userId = $user instanceof User ? $user->id : $user;
        $before = $this->periods->signature($userId);

        $transaction = DB::transaction(function () use ($userId, $data, $recurringRuleId, $recurringDate): Transaction {
            $transaction = new Transaction;
            $transaction->user_id = $userId;
            $transaction->fill(array_intersect_key($data, array_flip(self::EDITABLE)));
            $transaction->recurring_rule_id = $recurringRuleId;
            $transaction->recurring_date = $recurringDate === null ? null : SpanishCalendar::date($recurringDate);

            $this->assertValid($transaction, $data);

            if (array_key_exists('splits', $data) && is_array($data['splits']) && $data['splits'] !== []) {
                $transaction->category_id = null;
            }

            $transaction->save();
            $this->syncRelations($transaction, $data);
            $this->afterWrite($transaction, null);

            return $transaction;
        });

        $this->periodsChanged = $before !== $this->periods->signature($userId);

        return $transaction->refresh();
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Transaction $transaction, array $data): Transaction
    {
        if ($transaction->isTransfer()) {
            return $this->transfers->update($transaction, $data);
        }

        $before = $this->periods->signature($transaction->user_id);

        DB::transaction(function () use ($transaction, $data): void {
            $previous = [
                'payroll' => $this->periods->isPayroll($transaction),
                'date' => $transaction->date->toDateString(),
            ];

            $transaction->fill(array_intersect_key($data, array_flip(self::EDITABLE)));

            if (array_key_exists('splits', $data) && is_array($data['splits']) && $data['splits'] !== []) {
                $transaction->category_id = null;
            }

            $this->assertValid($transaction, $data);
            $transaction->save();
            $this->syncRelations($transaction, $data);
            $this->afterWrite($transaction, $previous);
        });

        $this->periodsChanged = $before !== $this->periods->signature($transaction->user_id);

        return $transaction->refresh();
    }

    public function delete(Transaction $transaction): void
    {
        $before = $this->periods->signature($transaction->user_id);

        DB::transaction(function () use ($transaction): void {
            if ($transaction->isTransfer()) {
                $this->transfers->delete($transaction);

                return;
            }

            if ($transaction->shares()->whereNotNull('settled_at')->exists()) {
                throw ValidationException::withMessages(['transaction' => 'Este gasto tiene partes compartidas ya liquidadas.']);
            }

            $wasPayroll = $this->periods->isPayroll($transaction);
            $openedPeriod = Period::query()->ownedBy($transaction->user_id)->where('opening_transaction_id', $transaction->id)->exists();

            SharedExpenseShare::query()->where('settlement_transaction_id', $transaction->id)->update([
                'settled_at' => null,
                'settlement_transaction_id' => null,
            ]);

            $transaction->delete();

            if ($wasPayroll && $openedPeriod) {
                $this->periods->rebuild($transaction->user_id);
            }

            TransactionSaved::dispatch($transaction->id, $transaction->user_id);
        });

        $this->periodsChanged = $before !== $this->periods->signature($transaction->user_id);
    }

    public function restore(Transaction $transaction): Transaction
    {
        $before = $this->periods->signature($transaction->user_id);

        DB::transaction(function () use ($transaction): void {
            if ($transaction->isTransfer() && $transaction->transfer_group_id !== null) {
                Transaction::query()->withoutGlobalScopes()->onlyTrashed()
                    ->where('transfer_group_id', $transaction->transfer_group_id)
                    ->get()
                    ->each(fn (Transaction $leg) => $leg->restore());

                return;
            }

            $transaction->restore();

            if ($this->periods->isPayroll($transaction)) {
                $this->periods->rebuild($transaction->user_id);
            }

            TransactionSaved::dispatch($transaction->id, $transaction->user_id);
        });

        $this->periodsChanged = $before !== $this->periods->signature($transaction->user_id);

        return $transaction->refresh();
    }

    /**
     * @param  list<string>  $ids
     * @param  array<string, mixed>  $changes
     */
    public function bulkUpdate(User $user, array $ids, array $changes): int
    {
        $transactions = Transaction::query()->ownedBy($user)->whereIn('id', $ids)->get();

        DB::transaction(function () use ($transactions, $changes): void {
            foreach ($transactions as $transaction) {
                $data = [];

                if (array_key_exists('category_id', $changes) && ! $transaction->isTransfer()) {
                    $data['category_id'] = $changes['category_id'];
                    if ($transaction->splits()->exists()) {
                        $data['splits'] = [];
                    }
                }

                if (array_key_exists('account_id', $changes) && ! $transaction->isTransfer()) {
                    $data['account_id'] = $changes['account_id'];
                }

                if (array_key_exists('status', $changes)) {
                    $data['status'] = $changes['status'];
                }

                $currentTags = $transaction->tags->pluck('name')->all();
                if (array_key_exists('tags', $changes)) {
                    $data['tags'] = $changes['tags'];
                }
                if (array_key_exists('add_tags', $changes) || array_key_exists('remove_tags', $changes)) {
                    $base = $data['tags'] ?? $currentTags;
                    $add = array_map(fn (string $tag) => TagService::normalize($tag), (array) ($changes['add_tags'] ?? []));
                    $remove = array_map(fn (string $tag) => TagService::normalize($tag), (array) ($changes['remove_tags'] ?? []));
                    $data['tags'] = array_values(array_diff(array_unique(array_merge($base, $add)), $remove));
                }

                if ($data !== []) {
                    $this->update($transaction, $data);
                }
            }
        });

        return $transactions->count();
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function assertValid(Transaction $transaction, array $data): void
    {
        $userId = $transaction->user_id;
        $errors = [];

        if ($transaction->kind === TransactionKind::Transfer) {
            $errors['kind'] = 'Usa el endpoint de transferencias para mover dinero entre cuentas.';
        }

        if ($transaction->kind === TransactionKind::Expense && $transaction->amount_cents >= 0) {
            $errors['amount_cents'] = 'Un gasto debe tener un importe negativo.';
        }

        if ($transaction->kind === TransactionKind::Income && $transaction->amount_cents <= 0) {
            $errors['amount_cents'] = 'Un ingreso debe tener un importe positivo.';
        }

        if ($transaction->amount_cents === 0) {
            $errors['amount_cents'] = 'El importe no puede ser cero.';
        }

        if (! Account::query()->ownedBy($userId)->whereKey($transaction->account_id)->exists()) {
            $errors['account_id'] = 'La cuenta no existe.';
        }

        if ($transaction->category_id !== null) {
            $category = Category::query()->ownedBy($userId)->whereKey($transaction->category_id)->first();
            if ($category === null) {
                $errors['category_id'] = 'La categoría no existe.';
            } elseif ($transaction->kind === TransactionKind::Adjustment || $category->kind->value !== $transaction->kind->value) {
                $errors['category_id'] = 'La categoría no corresponde al tipo de movimiento.';
            }
        }

        if ($transaction->debt_id !== null && ! Debt::query()->ownedBy($userId)->whereKey($transaction->debt_id)->exists()) {
            $errors['debt_id'] = 'La deuda no existe.';
        }

        $splits = $data['splits'] ?? null;
        if (is_array($splits) && $splits !== []) {
            if (! in_array($transaction->kind, [TransactionKind::Expense, TransactionKind::Income], true)) {
                $errors['splits'] = 'Solo se pueden dividir gastos e ingresos.';
            } else {
                $sum = 0;
                foreach ($splits as $index => $split) {
                    $amount = (int) $split['amount_cents'];
                    $sum += $amount;
                    if ($amount === 0 || ($amount < 0) !== ($transaction->amount_cents < 0)) {
                        $errors["splits.$index.amount_cents"] = 'Cada parte debe tener el mismo signo que el movimiento.';
                    }
                    $category = Category::query()->ownedBy($userId)->whereKey($split['category_id'])->first();
                    if ($category === null || $category->kind->value !== $transaction->kind->value) {
                        $errors["splits.$index.category_id"] = 'La categoría no corresponde al tipo de movimiento.';
                    }
                }
                if ($sum !== $transaction->amount_cents) {
                    $errors['splits'] = 'La suma de las partes debe coincidir con el importe.';
                }
            }
        }

        $shares = $data['shares'] ?? null;
        if (is_array($shares) && ($shares['items'] ?? []) !== []) {
            if ($transaction->kind !== TransactionKind::Expense) {
                $errors['shares'] = 'Solo se pueden compartir gastos.';
            }
            foreach ($shares['items'] as $index => $item) {
                if (! Contact::query()->ownedBy($userId)->whereKey($item['contact_id'])->exists()) {
                    $errors["shares.items.$index.contact_id"] = 'El contacto no existe.';
                }
            }
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function syncRelations(Transaction $transaction, array $data): void
    {
        if (array_key_exists('tags', $data) && is_array($data['tags'])) {
            $transaction->tags()->sync($this->tags->resolveIds($transaction->user_id, array_values(array_map('strval', $data['tags']))));
        }

        if (array_key_exists('splits', $data)) {
            $transaction->splits()->delete();
            foreach ((array) $data['splits'] as $split) {
                $transaction->splits()->save(new TransactionSplit([
                    'category_id' => $split['category_id'],
                    'amount_cents' => (int) $split['amount_cents'],
                ]));
            }
        }

        if (array_key_exists('shares', $data)) {
            $this->syncShares($transaction, ShareCalculator::normalize($data['shares']));
        } elseif ($transaction->kind !== TransactionKind::Expense) {
            $this->syncShares($transaction, null);
        } elseif ($transaction->wasChanged('amount_cents') && $transaction->shares()->exists()) {
            $this->resizeShares($transaction);
        }
    }

    /**
     * @param  array{mode: string, include_self?: bool, items: list<array{contact_id: string, percentage?: string|int|float|null, amount_cents?: int|null}>}|null  $spec
     */
    private function syncShares(Transaction $transaction, ?array $spec): void
    {
        $existing = $transaction->shares()->get();

        if ($existing->whereNotNull('settled_at')->isNotEmpty()) {
            throw ValidationException::withMessages(['shares' => 'No puedes cambiar un gasto compartido con partes ya liquidadas.']);
        }

        $calculated = $spec === null ? [] : ShareCalculator::withSpec($spec, $this->shareCalculator->calculate($transaction->amount_cents, $spec));

        $transaction->shares()->delete();
        foreach ($calculated as $share) {
            $transaction->shares()->save(new SharedExpenseShare($share));
        }
    }

    private function resizeShares(Transaction $transaction): void
    {
        $shares = $transaction->shares()->orderBy('created_at')->orderBy('id')->get();

        if ($shares->whereNotNull('settled_at')->isEmpty() && $shares->first()?->mode !== ShareMode::Amount) {
            $this->syncShares($transaction, ShareCalculator::specFrom($shares));

            return;
        }

        if ((int) $shares->sum('amount_cents') > abs($transaction->amount_cents)) {
            throw ValidationException::withMessages(['amount_cents' => 'El importe es menor que la parte compartida con tus contactos.']);
        }
    }

    /**
     * @param  array{payroll: bool, date: string}|null  $previous
     */
    private function afterWrite(Transaction $transaction, ?array $previous): void
    {
        $isPayroll = $this->periods->isPayroll($transaction);

        if ($previous === null) {
            if ($isPayroll) {
                PayrollRegistered::dispatch($transaction);
            } else {
                $this->periods->ensureBootstrapped($transaction->user_id, $transaction);
            }
        } elseif ($previous['payroll'] && (! $isPayroll || $previous['date'] !== $transaction->date->toDateString())) {
            $this->periods->rebuild($transaction->user_id);
        } elseif (! $previous['payroll'] && $isPayroll) {
            PayrollRegistered::dispatch($transaction);
        }

        TransactionSaved::dispatch($transaction->id, $transaction->user_id);
    }

    public function markCleared(Transaction $transaction): Transaction
    {
        return $this->update($transaction, ['status' => TransactionStatus::Cleared->value]);
    }
}
