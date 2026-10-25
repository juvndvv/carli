<?php

namespace App\Modules\Finance\BankSync\Data;

use Carbon\CarbonImmutable;

final readonly class BankSession
{
    /**
     * @param  list<BankAccount>  $accounts
     */
    public function __construct(
        public string $sessionId,
        public CarbonImmutable $validUntil,
        public array $accounts,
    ) {}
}
