<?php

namespace App\Modules\Finance\Calendar;

use App\Core\Calendar\CalendarItem;
use App\Core\Calendar\CalendarItemsProvider;
use App\Models\User;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Pending\FinancePendingItems;
use Carbon\CarbonImmutable;

/**
 * Expected charges and incomes of the recurring rules, from today on (past ones are real movements).
 */
final class FinanceCalendarItems implements CalendarItemsProvider
{
    public const string SOURCE = 'finance';

    public function moduleId(): string
    {
        return FinancePendingItems::MODULE;
    }

    public function items(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $today = SpanishCalendar::today();

        if ($to->lt($today)) {
            return [];
        }

        $rules = RecurringRule::query()->ownedBy($user)
            ->whereNull('cancelled_at')
            ->whereNotNull('next_occurrence')
            ->where('next_occurrence', '<=', $to->toDateString())
            ->with('category')
            ->get();

        $items = [];

        foreach ($rules as $rule) {
            $start = $from->max($today)->max($rule->next_occurrence ?? $today);

            foreach (RecurringService::schedule($rule)->between($start, $to) as $date) {
                $sign = match ($rule->kind) {
                    TransactionKind::Income => '+',
                    TransactionKind::Expense => '−',
                    default => '',
                };
                $items[] = new CalendarItem(
                    source: self::SOURCE,
                    id: $rule->id.':'.$date->toDateString(),
                    title: $rule->payee ?: ($rule->description ?: ($rule->category->name ?? 'Recurrente')),
                    date: CarbonImmutable::createFromFormat('!Y-m-d', $date->toDateString(), $today->getTimezone()) ?: $date,
                    subtitle: $sign.self::euros($rule->amount_cents).($rule->is_subscription ? ' · suscripción' : ''),
                    url: '/finanzas/recurrentes',
                    meta: [
                        'rule_id' => $rule->id,
                        'kind' => $rule->kind->value,
                        'amount_cents' => $rule->amount_cents,
                        'subscription' => $rule->is_subscription,
                    ],
                );
            }
        }

        return $items;
    }

    private static function euros(int $cents): string
    {
        return number_format(abs($cents) / 100, 2, ',', '.').' €';
    }
}
