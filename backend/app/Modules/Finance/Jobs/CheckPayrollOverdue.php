<?php

namespace App\Modules\Finance\Jobs;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\PeriodMode;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\FinanceSetting;
use App\Modules\Finance\Notifications\PayrollOverdue;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class CheckPayrollOverdue implements ShouldQueue
{
    use Queueable;

    public int $sent = 0;

    public function __construct(public readonly ?string $date = null) {}

    public function handle(PeriodService $periods): void
    {
        $today = $this->date === null ? SpanishCalendar::today() : SpanishCalendar::date($this->date);

        foreach (FinanceSetting::query()->withoutGlobalScopes()->where('period_mode', PeriodMode::Payroll->value)->get() as $settings) {
            $user = User::query()->find($settings->user_id);
            if ($user === null) {
                continue;
            }

            $period = $periods->current($user);
            $expectedEnd = $period->expected_end_date;

            if (! $expectedEnd instanceof CarbonImmutable || $period->payroll_overdue_notified_at !== null) {
                continue;
            }

            if ($today->greaterThan($expectedEnd->addDay())) {
                $period->payroll_overdue_notified_at = CarbonImmutable::now();
                $period->save();
                $user->notify(new PayrollOverdue($period->id));
                $this->sent++;
            }
        }
    }
}
