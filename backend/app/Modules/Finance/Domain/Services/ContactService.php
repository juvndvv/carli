<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\DebtDirection;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\SharedExpenseShare;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class ContactService
{
    public function __construct(private readonly TransactionService $transactions) {}

    /**
     * @return array{balance_cents: int, shares_pending_cents: int, owed_to_me_cents: int, i_owe_cents: int}
     */
    public function balance(Contact $contact): array
    {
        $shares = (int) $this->pendingShares($contact)->sum('amount_cents');
        $owedToMe = 0;
        $iOwe = 0;

        foreach (Debt::query()->ownedBy($contact->user_id)->where('contact_id', $contact->id)->whereNull('closed_at')->get() as $debt) {
            if ($debt->direction === DebtDirection::OwedToMe) {
                $owedToMe += $debt->pendingCents();
            } else {
                $iOwe += $debt->pendingCents();
            }
        }

        return [
            'balance_cents' => $shares + $owedToMe - $iOwe,
            'shares_pending_cents' => $shares,
            'owed_to_me_cents' => $owedToMe,
            'i_owe_cents' => $iOwe,
        ];
    }

    /**
     * @return Builder<SharedExpenseShare>
     */
    public function pendingShares(Contact $contact): Builder
    {
        return SharedExpenseShare::query()
            ->where('contact_id', $contact->id)
            ->whereNull('settled_at')
            ->whereHas('transaction', fn (Builder $query) => $query->whereNull('deleted_at'));
    }

    /**
     * @param  array{account_id: string, date?: string|null}  $data
     * @return array{transaction: Transaction, transactions: list<Transaction>, net_cents: int}
     */
    public function settle(Contact $contact, array $data): array
    {
        return DB::transaction(function () use ($contact, $data): array {
            $date = $data['date'] ?? SpanishCalendar::today()->toDateString();
            $shares = $this->pendingShares($contact)->lockForUpdate()->get();
            $sharesTotal = (int) $shares->sum('amount_cents');
            $debts = Debt::query()->ownedBy($contact->user_id)
                ->where('contact_id', $contact->id)
                ->whereNull('closed_at')
                ->lockForUpdate()
                ->get()
                ->filter(fn (Debt $debt) => $debt->pendingCents() > 0);

            if ($sharesTotal <= 0 && $debts->isEmpty()) {
                throw ValidationException::withMessages(['contact' => 'No hay saldo pendiente con este contacto.']);
            }

            $created = [];

            if ($sharesTotal > 0) {
                $settlement = $this->transactions->create($contact->user_id, [
                    'account_id' => $data['account_id'],
                    'kind' => TransactionKind::Income->value,
                    'amount_cents' => $sharesTotal,
                    'date' => $date,
                    'payee' => $contact->name,
                    'description' => 'Liquidación · '.$contact->name,
                ]);

                SharedExpenseShare::query()->whereIn('id', $shares->pluck('id'))->update([
                    'settled_at' => CarbonImmutable::now(),
                    'settlement_transaction_id' => $settlement->id,
                ]);

                $created[] = $settlement;
            }

            foreach ($debts as $debt) {
                $pending = $debt->pendingCents();
                $iOwe = $debt->direction === DebtDirection::IOwe;

                $created[] = $this->transactions->create($contact->user_id, [
                    'account_id' => $data['account_id'],
                    'kind' => $iOwe ? TransactionKind::Expense->value : TransactionKind::Income->value,
                    'amount_cents' => $iOwe ? -$pending : $pending,
                    'date' => $date,
                    'payee' => $contact->name,
                    'description' => 'Liquidación · '.$debt->name,
                    'debt_id' => $debt->id,
                ]);
            }

            return [
                'transaction' => $created[0],
                'transactions' => $created,
                'net_cents' => array_sum(array_map(fn (Transaction $transaction) => $transaction->amount_cents, $created)),
            ];
        });
    }

    public function create(User $user, string $name, ?string $notes): Contact
    {
        $contact = new Contact(['name' => $name, 'notes' => $notes]);
        $contact->user_id = $user->id;
        $contact->save();

        return $contact;
    }

    public function delete(Contact $contact): void
    {
        $hasHistory = SharedExpenseShare::query()->where('contact_id', $contact->id)->exists()
            || Debt::query()->ownedBy($contact->user_id)->where('contact_id', $contact->id)->exists();

        if ($hasHistory) {
            throw ValidationException::withMessages(['contact' => 'El contacto tiene gastos compartidos o deudas. Archívalo en lugar de borrarlo.']);
        }

        $contact->delete();
    }
}
