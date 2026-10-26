<?php

namespace App\Modules\Finance\Domain\Support;

use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;

final readonly class TransferCandidate
{
    /**
     * @param  list<string>  $signals
     */
    public function __construct(
        public Transaction $outgoing,
        public Transaction $incoming,
        public array $signals,
        public bool $unique,
    ) {}

    public function isClear(): bool
    {
        return $this->unique && $this->signals !== [];
    }

    public function isAutoConvertible(): bool
    {
        return $this->isClear() && $this->outgoing->category_id === null && $this->incoming->category_id === null;
    }

    public function daysApart(): int
    {
        return (int) abs($this->outgoing->date->diffInDays($this->incoming->date, false));
    }

    public function latestDate(): CarbonImmutable
    {
        return $this->outgoing->date->max($this->incoming->date);
    }

    public function key(): string
    {
        return $this->outgoing->id.'|'.$this->incoming->id;
    }
}
