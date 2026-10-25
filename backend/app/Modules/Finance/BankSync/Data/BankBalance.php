<?php

namespace App\Modules\Finance\BankSync\Data;

use Carbon\CarbonImmutable;

final readonly class BankBalance
{
    public function __construct(
        public int $amountCents,
        public string $type,
        public ?CarbonImmutable $referenceDate = null,
    ) {}
}
