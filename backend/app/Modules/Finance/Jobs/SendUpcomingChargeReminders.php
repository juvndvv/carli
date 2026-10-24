<?php

namespace App\Modules\Finance\Jobs;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\RecurringMode;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Services\FinanceSettingsService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\DebtReminder;
use App\Modules\Finance\Notifications\RecurringPending;
use App\Modules\Finance\Notifications\UpcomingCharge;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class SendUpcomingChargeReminders implements ShouldQueue
{
    use Queueable;

    public int $sent = 0;

    public function __construct(public readonly ?string $date = null) {}

    public function handle(FinanceSettingsService $settings): void
    {
        $today = $this->date === null ? SpanishCalendar::today() : SpanishCalendar::date($this->date);
        $users = [];
        $user = function (string $id) use (&$users): ?User {
            return $users[$id] ??= User::query()->find($id);
        };

        $rules = RecurringRule::query()->withoutGlobalScopes()
            ->whereNull('cancelled_at')
            ->whereNotNull('next_occurrence')
            ->where('next_occurrence', '>=', $today->toDateString())
            ->where('next_occurrence', '<=', $today->addDays(31)->toDateString())
            ->get();

        foreach ($rules as $rule) {
            $occurrence = $rule->next_occurrence;
            if ($occurrence === null || $rule->remind_days_before < 1) {
                continue;
            }

            $daysUntil = (int) $today->diffInDays($occurrence);
            if ($daysUntil !== $rule->remind_days_before) {
                continue;
            }

            $user($rule->user_id)?->notify(new UpcomingCharge($rule->id, $rule->displayName(), $rule->amount_cents, $daysUntil, $occurrence->toDateString()));
            $this->sent++;
        }

        $pending = Transaction::query()->withoutGlobalScopes()
            ->whereNull('deleted_at')
            ->whereNotNull('recurring_rule_id')
            ->where('status', TransactionStatus::Pending->value)
            ->where('date', $today->toDateString())
            ->with('recurringRule')
            ->get();

        foreach ($pending as $transaction) {
            $rule = $transaction->recurringRule;
            if (! $rule instanceof RecurringRule || $rule->mode !== RecurringMode::Confirm) {
                continue;
            }

            $user($transaction->user_id)?->notify(new RecurringPending($rule->id, $transaction->id, $rule->displayName(), $transaction->amount_cents));
            $this->sent++;
        }

        $debts = Debt::query()->withoutGlobalScopes()->whereNull('closed_at')->whereNotNull('due_date')
            ->where('due_date', '>=', $today->toDateString())
            ->where('due_date', '<=', $today->addDays(30)->toDateString())
            ->get();

        foreach ($debts as $debt) {
            $dueDate = $debt->due_date;
            if (! $dueDate instanceof CarbonImmutable) {
                continue;
            }

            $daysUntil = (int) $today->diffInDays($dueDate);
            if ($daysUntil !== 0 && $daysUntil !== $settings->for($debt->user_id)->remind_days_before) {
                continue;
            }

            $user($debt->user_id)?->notify(new DebtReminder($debt->id, $debt->name, $debt->direction, $debt->pendingCents(), $daysUntil));
            $this->sent++;
        }
    }
}
