<?php

namespace App\Modules\Finance\Jobs;

use App\Models\User;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\FinanceSetting;
use App\Modules\Finance\Notifications\WeeklySummary;
use App\Modules\Finance\Queries\SpendingQuery;
use Carbon\CarbonInterface;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class SendWeeklySummaries implements ShouldQueue
{
    use Queueable;

    public int $sent = 0;

    public function __construct(public readonly ?string $date = null) {}

    public function handle(PeriodService $periods, SpendingQuery $spending): void
    {
        $today = $this->date === null ? SpanishCalendar::today() : SpanishCalendar::date($this->date);
        $weekStart = $today->subWeek()->startOfWeek(CarbonInterface::MONDAY);
        $weekEnd = $weekStart->addDays(6);
        $label = 'del '.SpanishCalendar::shortDate($weekStart).' al '.SpanishCalendar::shortDate($weekEnd);

        foreach (FinanceSetting::query()->withoutGlobalScopes()->get() as $settings) {
            $user = User::query()->find($settings->user_id);
            if ($user === null) {
                continue;
            }

            $period = $periods->current($user);

            $user->notify(new WeeklySummary(
                $label,
                $spending->ownSpendingTotal($user->id, $weekStart, $weekEnd),
                $spending->incomeTotal($user->id, $weekStart, $weekEnd),
                $spending->ownSpendingTotal($user->id, $period->start_date, $period->effectiveEndDate()),
            ));
            $this->sent++;
        }
    }
}
