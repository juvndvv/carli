<?php

namespace App\Modules\Finance\Domain\Services;

use App\Modules\Finance\Domain\Enums\ShareMode;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\SharedExpenseShare;
use App\Modules\Finance\Models\ShareSettlement;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use LogicException;

/**
 * Links incomes (usually Bizums imported from the bank) to the contacts' shares of an expense they
 * pay back. The linked part of an income stops counting as income, and the share already stops
 * counting as our spending, so a reimbursed bill only weighs what we actually paid for ourselves.
 */
final class ReimbursementService
{
    /**
     * Pays back the contact's share of an expense with the given incomes. When the contact had no
     * share yet, one is created with the incoming amount; when the incomes exceed the share, the share
     * grows into our own part. Whatever does not fit in the expense keeps counting as income.
     *
     * @param  list<string>  $incomeIds
     * @return array{expense: Transaction, incomes: list<Transaction>}
     */
    public function reimburseExpense(Transaction $expense, Contact $contact, array $incomeIds): array
    {
        return DB::transaction(function () use ($expense, $contact, $incomeIds): array {
            if ($expense->kind !== TransactionKind::Expense) {
                throw ValidationException::withMessages(['expense_id' => 'Solo se pueden reembolsar gastos.']);
            }

            $incomes = $this->lockIncomes($expense->user_id, $incomeIds);
            $available = $incomes->sum(fn (Transaction $income) => $this->availableCents($income));
            if ($available <= 0) {
                throw ValidationException::withMessages(['income_ids' => 'Estos ingresos ya están vinculados a otros gastos.']);
            }

            /** @var Collection<int, SharedExpenseShare> $shares */
            $shares = $expense->shares()->with('settlements')->lockForUpdate()->get();
            $share = $shares->firstWhere('contact_id', $contact->id);
            $free = abs($expense->amount_cents) - (int) $shares->sum('amount_cents');
            $pending = $share?->pendingCents() ?? 0;
            $grow = min(max(0, $available - $pending), $free);

            if ($pending + $grow <= 0) {
                throw ValidationException::withMessages(['expense_id' => $share === null
                    ? 'El gasto ya está repartido por completo entre tus contactos.'
                    : 'La parte de '.$contact->name.' en este gasto ya está liquidada.']);
            }

            if ($grow > 0) {
                // Fixed amounts from now on: the reimbursement, not a rule, says what each one paid.
                $expense->shares()->update(['mode' => ShareMode::Amount->value, 'basis_points' => null]);

                if ($share === null) {
                    $share = $expense->shares()->create([
                        'contact_id' => $contact->id,
                        'amount_cents' => $grow,
                        'mode' => ShareMode::Amount->value,
                        'include_self' => true,
                        'from_reimbursement' => true,
                    ]);
                } else {
                    $share->update(['amount_cents' => $share->amount_cents + $grow, 'settled_at' => null]);
                }
            }

            if ($share === null) {
                throw new LogicException('A reimbursed expense must end up with a share for the contact.');
            }

            $this->allocate(collect([$share->load('settlements')]), $incomes);
            TransactionSaved::dispatch($expense->id, $expense->user_id);

            return ['expense' => $expense->refresh(), 'incomes' => $this->fresh($incomes)];
        });
    }

    /**
     * Pays back the contact's pending shares, oldest expense first, with the given incomes.
     *
     * @param  list<string>  $incomeIds
     * @return list<Transaction>
     */
    public function settleContact(Contact $contact, array $incomeIds): array
    {
        return DB::transaction(function () use ($contact, $incomeIds): array {
            $incomes = $this->lockIncomes($contact->user_id, $incomeIds);
            if ($incomes->sum(fn (Transaction $income) => $this->availableCents($income)) <= 0) {
                throw ValidationException::withMessages(['income_ids' => 'Estos ingresos ya están vinculados a otros gastos.']);
            }

            $shares = $this->pendingShares($contact);
            if ($shares->isEmpty()) {
                throw ValidationException::withMessages(['contact' => 'No hay partes pendientes con este contacto.']);
            }

            $this->allocate($shares, $incomes);

            return $this->fresh($incomes);
        });
    }

    /**
     * Pays back every pending share of the contact with a single income created for it.
     */
    public function settleAllWith(Contact $contact, Transaction $income): void
    {
        $this->allocate($this->pendingShares($contact), collect([$income->load('settlements')]));
    }

    /**
     * Undoes every link of an income: it counts as income again and the shares it paid are pending.
     */
    public function unlink(Transaction $income): void
    {
        DB::transaction(function () use ($income): void {
            $shareIds = ShareSettlement::query()->where('transaction_id', $income->id)->pluck('share_id')->all();
            if ($shareIds === []) {
                return;
            }

            ShareSettlement::query()->where('transaction_id', $income->id)->delete();

            $expenseIds = [];
            foreach (SharedExpenseShare::query()->whereKey($shareIds)->with('settlements')->lockForUpdate()->get() as $share) {
                $expenseIds[] = $share->transaction_id;

                if ($share->from_reimbursement && $share->settlements->isEmpty()) {
                    $share->delete();
                } elseif ($share->pendingCents() > 0) {
                    $share->update(['settled_at' => null]);
                }
            }

            foreach (array_unique([$income->id, ...$expenseIds]) as $id) {
                TransactionSaved::dispatch($id, $income->user_id);
            }
        });
    }

    public function availableCents(Transaction $income): int
    {
        return max(0, $income->amount_cents - $income->reimbursedCents());
    }

    /**
     * Incomes that could pay back an expense, or a contact's shares: not linked yet, not older than
     * a week before the expense.
     *
     * @return EloquentCollection<int, Transaction>
     */
    public function incomeCandidates(string $userId, ?CarbonImmutable $since, int $limit = 50): EloquentCollection
    {
        return Transaction::query()->ownedBy($userId)
            ->where('kind', TransactionKind::Income->value)
            ->whereNull('transfer_group_id')
            ->whereNull('debt_id')
            ->when($since !== null, fn (Builder $query) => $query->where('date', '>=', $since?->subDays(7)->toDateString()))
            ->whereRaw('amount_cents > (SELECT COALESCE(SUM(ss.amount_cents), 0) FROM finance.share_settlements ss WHERE ss.transaction_id = finance.transactions.id)')
            ->orderByDesc('date')->orderByDesc('id')
            ->limit($limit)
            ->get();
    }

    /**
     * Expenses an income could pay back: on or before its date, within two months.
     *
     * @return EloquentCollection<int, Transaction>
     */
    public function expenseCandidates(Transaction $income, int $limit = 50): EloquentCollection
    {
        return Transaction::query()->ownedBy($income->user_id)
            ->where('kind', TransactionKind::Expense->value)
            ->whereNull('transfer_group_id')
            ->whereBetween('date', [$income->date->subMonths(2)->toDateString(), $income->date->addDays(7)->toDateString()])
            ->orderByDesc('date')->orderByDesc('id')
            ->limit($limit)
            ->get();
    }

    /**
     * @param  Collection<int, SharedExpenseShare>  $shares
     * @param  Collection<int, Transaction>  $incomes
     */
    private function allocate(Collection $shares, Collection $incomes): void
    {
        $available = [];
        foreach ($incomes as $income) {
            $available[$income->id] = $this->availableCents($income);
        }

        foreach ($shares as $share) {
            $need = $share->pendingCents();

            foreach ($incomes as $income) {
                if ($need <= 0) {
                    break;
                }

                $take = min($need, $available[$income->id]);
                if ($take <= 0) {
                    continue;
                }

                $link = ShareSettlement::query()->firstOrNew(['share_id' => $share->id, 'transaction_id' => $income->id]);
                $link->amount_cents = ($link->exists ? $link->amount_cents : 0) + $take;
                $link->save();

                $available[$income->id] -= $take;
                $need -= $take;
            }

            if ($need <= 0 && $share->settled_at === null) {
                $share->update(['settled_at' => CarbonImmutable::now()]);
            }
        }

        foreach ($incomes as $income) {
            TransactionSaved::dispatch($income->id, $income->user_id);
        }
    }

    /**
     * @param  Collection<int, Transaction>  $incomes
     * @return list<Transaction>
     */
    private function fresh(Collection $incomes): array
    {
        return array_values($incomes->map(fn (Transaction $income) => $income->refresh())->all());
    }

    /**
     * @return Collection<int, SharedExpenseShare>
     */
    private function pendingShares(Contact $contact): Collection
    {
        return SharedExpenseShare::query()
            ->where('contact_id', $contact->id)
            ->whereNull('settled_at')
            ->whereHas('transaction', fn (Builder $query) => $query->whereNull('deleted_at'))
            ->with(['settlements', 'transaction'])
            ->lockForUpdate()
            ->get()
            ->sortBy(fn (SharedExpenseShare $share) => $share->transaction->date->toDateString().$share->created_at?->toIso8601String())
            ->values();
    }

    /**
     * @param  list<string>  $ids
     * @return Collection<int, Transaction>
     */
    private function lockIncomes(string $userId, array $ids): Collection
    {
        $incomes = Transaction::query()->ownedBy($userId)
            ->whereKey(array_values(array_unique($ids)))
            ->orderBy('date')->orderBy('id')
            ->lockForUpdate()
            ->get();

        if ($incomes->count() !== count(array_unique($ids))) {
            throw ValidationException::withMessages(['income_ids' => 'Algún ingreso no existe.']);
        }

        if ($incomes->contains(fn (Transaction $income) => $income->kind !== TransactionKind::Income || $income->transfer_group_id !== null || $income->debt_id !== null)) {
            throw ValidationException::withMessages(['income_ids' => 'Solo se pueden vincular ingresos que no sean traspasos ni pagos de deudas.']);
        }

        return collect($incomes->load('settlements')->all());
    }
}
