<?php

namespace App\Modules\Finance\BankSync\Services;

use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Data\BankAccount;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use Illuminate\Support\Facades\DB;

final class BankAccountNameService
{
    public function __construct(private readonly BankDataProvider $provider) {}

    /**
     * @return list<array{account: Account, from: string, to: string}>
     */
    public function refresh(BankConnection $connection, bool $dryRun = false): array
    {
        $snapshot = [];
        foreach ($connection->accounts ?? [] as $entry) {
            $snapshot[$entry['uid']] = BankAccount::fromArray($entry);
        }

        foreach ($this->linkedAccounts($connection) as $account) {
            $uid = (string) $account->external_account_uid;
            $fresh = $this->provider->fetchAccount($uid);

            if ($fresh !== null) {
                $snapshot[$uid] = $this->merge($snapshot[$uid] ?? null, $fresh);
            }
        }

        $connection->accounts = array_values(array_map(fn (BankAccount $account) => $account->toArray(), $snapshot));
        $renames = $this->pendingRenames($connection);

        if (! $dryRun) {
            DB::transaction(function () use ($connection, $renames): void {
                $connection->save();
                $this->apply($renames);
            });
        }

        return $renames;
    }

    public function renameDefaults(BankConnection $connection): void
    {
        $this->apply($this->pendingRenames($connection));
    }

    /**
     * @return list<array{account: Account, from: string, to: string}>
     */
    private function pendingRenames(BankConnection $connection): array
    {
        $renames = [];

        foreach ($this->linkedAccounts($connection) as $account) {
            $entry = $connection->bankAccount((string) $account->external_account_uid);
            if ($entry === null) {
                continue;
            }

            $bankAccount = BankAccount::fromArray($entry);
            $suggested = $bankAccount->suggestedName($connection->aspsp_name);

            if ($account->name !== $suggested && in_array($account->name, $bankAccount->legacyNames($connection->aspsp_name), true)) {
                $renames[] = ['account' => $account, 'from' => $account->name, 'to' => $suggested];
            }
        }

        return $renames;
    }

    /**
     * @param  list<array{account: Account, from: string, to: string}>  $renames
     */
    private function apply(array $renames): void
    {
        foreach ($renames as $rename) {
            $rename['account']->forceFill(['name' => $rename['to']])->save();
        }
    }

    /**
     * @return iterable<Account>
     */
    private function linkedAccounts(BankConnection $connection): iterable
    {
        return Account::query()->ownedBy($connection->user_id)
            ->where('bank_connection_id', $connection->id)
            ->whereNotNull('external_account_uid')
            ->orderBy('created_at')
            ->get();
    }

    private function merge(?BankAccount $previous, BankAccount $fresh): BankAccount
    {
        return new BankAccount(
            uid: $fresh->uid,
            identificationHash: $fresh->identificationHash ?? $previous?->identificationHash,
            name: $fresh->name ?? $previous?->name,
            iban: $fresh->iban ?? $previous?->iban,
            currency: $fresh->currency ?? $previous?->currency,
            type: $fresh->type ?? $previous?->type,
            details: $fresh->details,
            product: $fresh->product,
        );
    }
}
