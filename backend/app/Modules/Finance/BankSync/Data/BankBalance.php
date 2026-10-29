<?php

namespace App\Modules\Finance\BankSync\Data;

use Carbon\CarbonImmutable;

final readonly class BankBalance
{
    /**
     * @param  array<string, int>  $all  every balance type the bank reported, in cents
     */
    public function __construct(
        public int $amountCents,
        public string $type,
        public ?CarbonImmutable $referenceDate = null,
        public array $all = [],
    ) {}
}
