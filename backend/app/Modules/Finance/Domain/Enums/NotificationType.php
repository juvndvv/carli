<?php

namespace App\Modules\Finance\Domain\Enums;

enum NotificationType: string
{
    case BudgetThreshold = 'budget_threshold';

    case UpcomingCharge = 'upcoming_charge';

    case RecurringPending = 'recurring_pending';

    case GoalReached = 'goal_reached';

    case DebtReminder = 'debt_reminder';

    case PayrollOverdue = 'payroll_overdue';

    case WeeklySummary = 'weekly_summary';

    case BankConsentExpiring = 'bank_consent_expiring';

    case BankSyncFailed = 'bank_sync_failed';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
