<?php

namespace App\Modules\Finance\Jobs;

use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class MaterializeRecurringJob implements ShouldQueue
{
    use Queueable;

    public int $created = 0;

    public function __construct(public readonly ?string $date = null) {}

    public function handle(RecurringService $recurring): void
    {
        $this->created = $recurring->materializeDue($this->date === null ? null : SpanishCalendar::date($this->date));
    }
}
