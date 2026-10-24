<?php

namespace App\Modules\Finance\Domain\Support;

use App\Modules\Finance\Domain\Enums\PeriodOpenedBy;
use Carbon\CarbonImmutable;

final class PeriodRange
{
    public function __construct(
        public CarbonImmutable $start,
        public PeriodOpenedBy $openedBy,
        public ?string $openingTransactionId = null,
        public ?CarbonImmutable $end = null,
    ) {}

    public function overlaps(CarbonImmutable $start, ?CarbonImmutable $end): bool
    {
        $startsBeforeOtherEnds = $end === null || $this->start->lessThanOrEqualTo($end);
        $endsAfterOtherStarts = $this->end === null || $this->end->greaterThanOrEqualTo($start);

        return $startsBeforeOtherEnds && $endsAfterOtherStarts;
    }
}
