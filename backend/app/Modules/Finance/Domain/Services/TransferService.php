<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class TransferService
{
    private const string BANK_LOCKED = 'Esta transferencia viene del banco: el importe y la fecha no se pueden cambiar.';

    public function __construct(
        private readonly TagService $tags,
        private readonly PeriodService $periods,
    ) {}

    /**
     * @param  array{from_account_id: string, to_account_id: string, amount_cents: int, date: string, description?: string|null, notes?: string|null, status?: string|null, tags?: list<string>|null}  $data
     * @return array{from: Transaction, to: Transaction}
     */
    public function create(User|string $user, array $data): array
    {
        $userId = $user instanceof User ? $user->id : $user;

        if ($data['from_account_id'] === $data['to_account_id']) {
            throw ValidationException::withMessages(['to_account_id' => 'Las cuentas de origen y destino deben ser distintas.']);
        }

        if ($data['amount_cents'] <= 0) {
            throw ValidationException::withMessages(['amount_cents' => 'El importe debe ser positivo.']);
        }

        $accounts = Account::query()->ownedBy($userId)->whereIn('id', [$data['from_account_id'], $data['to_account_id']])->get()->keyBy('id');
        $from = $accounts->get($data['from_account_id']);
        $to = $accounts->get($data['to_account_id']);

        if ($from === null || $to === null) {
            throw ValidationException::withMessages(['from_account_id' => 'La cuenta no existe.']);
        }

        return DB::transaction(function () use ($userId, $data, $from, $to): array {
            $groupId = (string) Str::uuid7();
            $common = [
                'kind' => TransactionKind::Transfer->value,
                'date' => $data['date'],
                'description' => $data['description'] ?? null,
                'notes' => $data['notes'] ?? null,
                'status' => $data['status'] ?? TransactionStatus::Cleared->value,
                'transfer_group_id' => $groupId,
            ];

            $outgoing = $this->leg($userId, $common + ['account_id' => $from->id, 'amount_cents' => -$data['amount_cents'], 'payee' => $to->name]);
            $incoming = $this->leg($userId, $common + ['account_id' => $to->id, 'amount_cents' => $data['amount_cents'], 'payee' => $from->name]);

            if (isset($data['tags'])) {
                $tagIds = $this->tags->resolveIds($userId, $data['tags']);
                $outgoing->tags()->sync($tagIds);
                $incoming->tags()->sync($tagIds);
            }

            $this->periods->ensureBootstrapped($userId, $outgoing);

            TransactionSaved::dispatch($outgoing->id, $userId);
            TransactionSaved::dispatch($incoming->id, $userId);

            return ['from' => $outgoing->refresh(), 'to' => $incoming->refresh()];
        });
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Transaction $leg, array $data): Transaction
    {
        if (array_key_exists('account_id', $data) && $data['account_id'] !== $leg->account_id) {
            throw ValidationException::withMessages(['account_id' => 'Para cambiar las cuentas de una transferencia, bórrala y créala de nuevo.']);
        }

        if (array_key_exists('kind', $data) && $data['kind'] !== TransactionKind::Transfer->value) {
            throw ValidationException::withMessages(['kind' => 'No se puede cambiar el tipo de una transferencia.']);
        }

        DB::transaction(function () use ($leg, $data): void {
            $legs = $this->legs($leg);
            $this->assertBankFieldsUnchanged($legs, $data);
            $magnitude = array_key_exists('amount_cents', $data) ? abs((int) $data['amount_cents']) : null;

            if ($magnitude === 0) {
                throw ValidationException::withMessages(['amount_cents' => 'El importe no puede ser cero.']);
            }

            foreach ($legs as $each) {
                foreach (['date', 'description', 'notes', 'status'] as $field) {
                    if (array_key_exists($field, $data)) {
                        $each->setAttribute($field, $data[$field]);
                    }
                }

                if ($magnitude !== null) {
                    $each->amount_cents = $each->amount_cents < 0 ? -$magnitude : $magnitude;
                }

                $each->save();

                if (array_key_exists('tags', $data) && is_array($data['tags'])) {
                    $each->tags()->sync($this->tags->resolveIds($each->user_id, array_values(array_map('strval', $data['tags']))));
                }

                TransactionSaved::dispatch($each->id, $each->user_id);
            }
        });

        return $leg->refresh();
    }

    public function delete(Transaction $leg): void
    {
        DB::transaction(function () use ($leg): void {
            foreach ($this->legs($leg) as $each) {
                $each->delete();
                TransactionSaved::dispatch($each->id, $each->user_id);
            }
        });
    }

    /**
     * @param  list<Transaction>  $legs
     * @param  array<string, mixed>  $data
     */
    private function assertBankFieldsUnchanged(array $legs, array $data): void
    {
        foreach ($legs as $each) {
            if ($each->source !== TransactionSource::Bank) {
                continue;
            }

            if (array_key_exists('amount_cents', $data) && abs((int) $data['amount_cents']) !== abs($each->amount_cents)) {
                throw ValidationException::withMessages(['amount_cents' => self::BANK_LOCKED]);
            }

            if (array_key_exists('date', $data) && (string) $data['date'] !== $each->date->toDateString()) {
                throw ValidationException::withMessages(['date' => self::BANK_LOCKED]);
            }
        }
    }

    /**
     * @return list<Transaction>
     */
    private function legs(Transaction $leg): array
    {
        return array_values(Transaction::query()
            ->ownedBy($leg->user_id)
            ->where('transfer_group_id', $leg->transfer_group_id)
            ->get()
            ->all());
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function leg(string $userId, array $attributes): Transaction
    {
        $transaction = new Transaction;
        $transaction->user_id = $userId;
        $transaction->fill($attributes);
        $transaction->save();

        return $transaction;
    }
}
