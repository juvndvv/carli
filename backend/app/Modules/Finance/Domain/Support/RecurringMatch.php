<?php

namespace App\Modules\Finance\Domain\Support;

use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;

final readonly class RecurringMatch
{
    public function __construct(
        public RecurringRule $rule,
        public CarbonImmutable $occurrence,
        public ?Transaction $expected,
        public bool $merchantMatched,
        public int $amountGapCents,
        public int $daysApart,
    ) {}

    public function isCloserThan(self $other): bool
    {
        return [! $this->merchantMatched, $this->amountGapCents, $this->daysApart]
            < [! $other->merchantMatched, $other->amountGapCents, $other->daysApart];
    }
}
