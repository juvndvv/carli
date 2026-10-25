<?php

namespace App\Modules\Finance\BankSync\Contracts;

use App\Modules\Finance\BankSync\Data\Aspsp;
use App\Modules\Finance\BankSync\Data\BankAccount;
use App\Modules\Finance\BankSync\Data\BankBalance;
use App\Modules\Finance\BankSync\Data\BankSession;
use App\Modules\Finance\BankSync\Data\PsuContext;
use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use Carbon\CarbonImmutable;

interface BankDataProvider
{
    public function id(): string;

    /**
     * @return list<Aspsp>
     *
     * @throws BankProviderException
     */
    public function listAspsps(string $country): array;

    /**
     * @throws BankProviderException
     */
    public function startAuth(Aspsp $aspsp, string $redirectUrl, string $state, CarbonImmutable $validUntil): string;

    /**
     * @throws BankProviderException
     */
    public function completeAuth(string $code): BankSession;

    /**
     * @return list<BankAccount>
     *
     * @throws BankProviderException
     */
    public function listAccounts(string $sessionId): array;

    /**
     * @return list<array<string, mixed>>
     *
     * @throws BankProviderException
     */
    public function fetchTransactions(string $accountUid, CarbonImmutable $from, CarbonImmutable $to, ?PsuContext $psu = null): array;

    /**
     * @throws BankProviderException
     */
    public function fetchBalance(string $accountUid, ?PsuContext $psu = null): ?BankBalance;

    /**
     * @throws BankProviderException
     */
    public function revoke(string $sessionId): void;
}
