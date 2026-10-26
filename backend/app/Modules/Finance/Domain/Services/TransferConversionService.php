<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Enums\TransferSource;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Models\TransferExclusion;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class TransferConversionService
{
    public function __construct(private readonly PeriodService $periods) {}

    /**
     * @return array{from: Transaction, to: Transaction}
     */
    public function convert(Transaction $outgoing, Transaction $incoming, TransferSource $source): array
    {
        $this->assertConvertible($outgoing, 'outgoing_transaction_id');
        $this->assertConvertible($incoming, 'incoming_transaction_id');

        $errors = [];
        if ($outgoing->user_id !== $incoming->user_id || $outgoing->account_id === $incoming->account_id) {
            $errors['incoming_transaction_id'] = 'Los movimientos deben ser de dos cuentas distintas.';
        } elseif ($outgoing->amount_cents >= 0 || $incoming->amount_cents !== -$outgoing->amount_cents) {
            $errors['incoming_transaction_id'] = 'Los importes de los dos movimientos no coinciden.';
        } elseif (abs($outgoing->date->diffInDays($incoming->date, false)) > TransferDetector::MAX_DAYS_APART) {
            $errors['incoming_transaction_id'] = 'Las fechas de los dos movimientos están demasiado separadas.';
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return DB::transaction(function () use ($outgoing, $incoming, $source): array {
            $rebuild = $this->opensPeriod($incoming);
            $groupId = (string) Str::uuid7();

            foreach ([$outgoing, $incoming] as $leg) {
                $this->markAsLeg($leg, $groupId, $source);
            }

            if ($rebuild) {
                $this->periods->rebuild($outgoing->user_id);
            }

            TransactionSaved::dispatch($outgoing->id, $outgoing->user_id);
            TransactionSaved::dispatch($incoming->id, $incoming->user_id);

            return ['from' => $outgoing->refresh(), 'to' => $incoming->refresh()];
        });
    }

    /**
     * @return array{from: Transaction, to: Transaction}
     */
    public function link(Transaction $imported, string $accountId, TransferSource $source = TransferSource::Linked): array
    {
        $this->assertConvertible($imported, 'transaction');

        $account = Account::query()->ownedBy($imported->user_id)->whereKey($accountId)->first();

        if ($account === null) {
            throw ValidationException::withMessages(['account_id' => 'La cuenta no existe.']);
        }

        $error = match (true) {
            $account->id === $imported->account_id => 'Elige una cuenta distinta a la del movimiento.',
            $account->isBankLinked() => 'Esa cuenta está conectada al banco: sus movimientos se emparejan solos.',
            $account->isArchived() => 'La cuenta está archivada.',
            default => null,
        };

        if ($error !== null) {
            throw ValidationException::withMessages(['account_id' => $error]);
        }

        return DB::transaction(function () use ($imported, $account, $source): array {
            $rebuild = $this->opensPeriod($imported);
            $groupId = (string) Str::uuid7();

            $counterpart = new Transaction;
            $counterpart->user_id = $imported->user_id;
            $counterpart->fill([
                'account_id' => $account->id,
                'kind' => TransactionKind::Transfer,
                'amount_cents' => -$imported->amount_cents,
                'date' => $imported->date,
                'payee' => $imported->account->name,
                'description' => $imported->description,
                'status' => TransactionStatus::Cleared,
            ]);
            $counterpart->source = TransactionSource::Manual;
            $counterpart->transfer_group_id = $groupId;
            $counterpart->transfer_source = $source;
            $counterpart->transfer_detected_at = CarbonImmutable::now();
            $counterpart->save();

            $this->markAsLeg($imported, $groupId, $source);

            if ($rebuild) {
                $this->periods->rebuild($imported->user_id);
            }

            TransactionSaved::dispatch($imported->id, $imported->user_id);
            TransactionSaved::dispatch($counterpart->id, $counterpart->user_id);

            $legs = [$imported->refresh(), $counterpart->refresh()];
            usort($legs, fn (Transaction $a, Transaction $b) => $a->amount_cents <=> $b->amount_cents);

            return ['from' => $legs[0], 'to' => $legs[1]];
        });
    }

    /**
     * @return list<Transaction>
     */
    public function undo(Transaction $leg): array
    {
        if (! $leg->isConvertedTransfer() || $leg->transfer_group_id === null) {
            throw ValidationException::withMessages(['transaction' => 'Esta transferencia no se creó a partir de movimientos del banco.']);
        }

        return DB::transaction(function () use ($leg): array {
            $legs = Transaction::query()->ownedBy($leg->user_id)
                ->where('transfer_group_id', $leg->transfer_group_id)
                ->lockForUpdate()
                ->get();

            $imported = $legs->filter(fn (Transaction $each) => $each->source === TransactionSource::Bank)->values();
            $createdAutomatically = $leg->transfer_source === TransferSource::Auto && $legs->contains(fn (Transaction $each) => $each->source !== TransactionSource::Bank);

            foreach ($legs as $each) {
                if ($each->source !== TransactionSource::Bank) {
                    $each->forceDelete();
                    TransactionSaved::dispatch($each->id, $each->user_id);
                }
            }

            foreach ($imported as $each) {
                $each->kind = $each->amount_cents < 0 ? TransactionKind::Expense : TransactionKind::Income;
                $each->category_id = null;
                $each->transfer_group_id = null;
                $each->transfer_source = null;
                $each->transfer_detected_at = null;
                $each->save();
                TransactionSaved::dispatch($each->id, $each->user_id);
            }

            $outgoing = $imported->first(fn (Transaction $each) => $each->amount_cents < 0);
            $incoming = $imported->first(fn (Transaction $each) => $each->amount_cents > 0);
            if ($outgoing !== null && $incoming !== null) {
                $this->exclude($leg->user_id, $outgoing->id, $incoming->id);
            }

            $only = $imported->count() === 1 ? $imported->first() : null;
            if ($createdAutomatically && $only !== null) {
                $this->exclude($leg->user_id, $only->id, $only->id);
            }

            return array_values($imported->map(fn (Transaction $each) => $each->refresh())->all());
        });
    }

    public function dismiss(User $user, string $outgoingId, string $incomingId): void
    {
        $found = Transaction::query()->ownedBy($user)->whereIn('id', [$outgoingId, $incomingId])->count();

        if ($outgoingId === $incomingId || $found !== 2) {
            throw ValidationException::withMessages(['outgoing_transaction_id' => 'Los movimientos no existen.']);
        }

        $this->exclude($user->id, $outgoingId, $incomingId);
    }

    private function exclude(string $userId, string $outgoingId, string $incomingId): void
    {
        $exclusion = TransferExclusion::query()->ownedBy($userId)->firstOrNew([
            'outgoing_transaction_id' => $outgoingId,
            'incoming_transaction_id' => $incomingId,
        ]);
        $exclusion->user_id = $userId;
        $exclusion->save();
    }

    private function assertConvertible(Transaction $transaction, string $field): void
    {
        $error = match (true) {
            $transaction->trashed() => 'El movimiento está borrado.',
            $transaction->source !== TransactionSource::Bank => 'Solo se pueden convertir movimientos importados del banco.',
            $transaction->isTransfer() => 'El movimiento ya es una transferencia.',
            ! in_array($transaction->kind, [TransactionKind::Expense, TransactionKind::Income], true) => 'Solo se pueden convertir gastos e ingresos.',
            $transaction->debt_id !== null => 'El movimiento es un pago de una deuda.',
            $transaction->splits()->exists() => 'El movimiento está dividido en varias categorías.',
            $transaction->shares()->exists() || $transaction->settledShares()->exists() => 'El movimiento tiene partes compartidas.',
            default => null,
        };

        if ($error !== null) {
            throw ValidationException::withMessages([$field => $error]);
        }
    }

    private function opensPeriod(Transaction $transaction): bool
    {
        return $this->periods->isPayroll($transaction)
            || Period::query()->ownedBy($transaction->user_id)->where('opening_transaction_id', $transaction->id)->exists();
    }

    private function markAsLeg(Transaction $leg, string $groupId, TransferSource $source): void
    {
        $leg->kind = TransactionKind::Transfer;
        $leg->category_id = null;
        $leg->transfer_group_id = $groupId;
        $leg->transfer_source = $source;
        $leg->transfer_detected_at = CarbonImmutable::now();
        $leg->save();
    }
}
