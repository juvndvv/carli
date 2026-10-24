<?php

namespace App\Modules\Finance\Domain\Services;

use App\Modules\Finance\Domain\Enums\RecurrenceFrequency;
use Carbon\CarbonImmutable;

final readonly class RecurrenceSchedule
{
    public function __construct(
        public RecurrenceFrequency $frequency,
        public int $interval,
        public CarbonImmutable $start,
        public ?CarbonImmutable $end = null,
        public ?int $dayOfMonth = null,
    ) {}

    public function occurrence(int $index): CarbonImmutable
    {
        $step = $index * max(1, $this->interval);

        return match ($this->frequency) {
            RecurrenceFrequency::Daily => $this->start->addDays($step),
            RecurrenceFrequency::Weekly => $this->start->addWeeks($step),
            RecurrenceFrequency::Monthly => $this->monthly($this->start->startOfMonth()->addMonthsNoOverflow($step)),
            RecurrenceFrequency::Yearly => $this->monthly($this->start->startOfMonth()->addYearsNoOverflow($step)),
        };
    }

    public function firstOnOrAfter(CarbonImmutable $date): ?CarbonImmutable
    {
        $index = $this->estimateIndex($date);

        while ($index > 0 && $this->occurrence($index - 1)->greaterThanOrEqualTo($date)) {
            $index--;
        }

        while ($this->occurrence($index)->lessThan($date) || $this->occurrence($index)->lessThan($this->start)) {
            $index++;
        }

        $occurrence = $this->occurrence($index);

        return $this->end !== null && $occurrence->greaterThan($this->end) ? null : $occurrence;
    }

    public function first(): ?CarbonImmutable
    {
        return $this->firstOnOrAfter($this->start);
    }

    public function after(CarbonImmutable $date): ?CarbonImmutable
    {
        return $this->firstOnOrAfter($date->addDay());
    }

    /**
     * @return list<CarbonImmutable>
     */
    public function between(CarbonImmutable $from, CarbonImmutable $to): array
    {
        $dates = [];
        $cursor = $this->firstOnOrAfter($from);

        while ($cursor !== null && $cursor->lessThanOrEqualTo($to)) {
            $dates[] = $cursor;
            $cursor = $this->after($cursor);
        }

        return $dates;
    }

    private function monthly(CarbonImmutable $monthStart): CarbonImmutable
    {
        $day = min($this->dayOfMonth ?? $this->start->day, $monthStart->daysInMonth);

        return $monthStart->setDay($day);
    }

    private function estimateIndex(CarbonImmutable $date): int
    {
        if ($date->lessThanOrEqualTo($this->start)) {
            return 0;
        }

        $interval = max(1, $this->interval);

        $units = match ($this->frequency) {
            RecurrenceFrequency::Daily => (int) $this->start->diffInDays($date),
            RecurrenceFrequency::Weekly => intdiv((int) $this->start->diffInDays($date), 7),
            RecurrenceFrequency::Monthly => ($date->year - $this->start->year) * 12 + $date->month - $this->start->month,
            RecurrenceFrequency::Yearly => $date->year - $this->start->year,
        };

        return max(0, intdiv($units, $interval));
    }
}
