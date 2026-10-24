<?php

namespace App\Modules\Finance\Listeners;

use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Events\PayrollRegistered;

final readonly class OpenPeriodOnPayroll
{
    public function __construct(private PeriodService $periods) {}

    public function handle(PayrollRegistered $event): void
    {
        $event->periodOpened = $this->periods->handlePayroll($event->transaction);
    }
}
