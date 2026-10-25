<?php

namespace App\Modules\Finance\Queries;

use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Domain\Support\PeriodPresenter;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Http\Resources\CategorySummary;
use App\Modules\Finance\Http\Resources\PeriodResource;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Http\Request;

final readonly class DashboardQuery
{
    public function __construct(
        private PeriodService $periods,
        private SpendingQuery $spending,
        private NetWorthQuery $netWorth,
        private BudgetService $budgets,
        private RecurringService $recurring,
    ) {}

    /**
     * @return array{income_cents: int, expense_cents: int, savings_cents: int, savings_rate_bp: int|null}
     */
    public function kpis(Period $period): array
    {
        $end = $period->effectiveEndDate();
        $income = $this->spending->incomeTotal($period->user_id, $period->start_date, $end);
        $expense = $this->spending->ownSpendingTotal($period->user_id, $period->start_date, $end);

        return [
            'income_cents' => $income,
            'expense_cents' => $expense,
            'savings_cents' => $income - $expense,
            'savings_rate_bp' => Money::ofCents($income - $expense)->ratioBasisPoints($income),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function build(Period $period, Request $request): array
    {
        $userId = $period->user_id;
        $previous = $this->periods->previous($period);
        $today = SpanishCalendar::today();
        $netWorthDate = $period->isOpen() ? $today : ($period->end_date ?? $today);

        $current = $this->kpis($period);
        $before = $previous === null ? null : $this->kpis($previous);

        $netWorth = $period->isOpen() ? $this->netWorth->current($userId) : $this->netWorth->at($userId, $netWorthDate);
        $netWorthPrevious = $previous === null ? null : $this->netWorth->at($userId, $previous->effectiveEndDate()->min($today));

        $budgetRows = $this->budgets->overview($period);
        usort($budgetRows, fn (array $left, array $right) => ($right['percent_bp'] ?? 0) <=> ($left['percent_bp'] ?? 0));

        return [
            'period' => PeriodResource::present($period),
            'previous_period' => $previous === null ? null : PeriodResource::present($previous),
            'net_worth_cents' => $netWorth,
            'net_worth_previous_cents' => $netWorthPrevious,
            'net_worth_delta_cents' => $netWorthPrevious === null ? null : $netWorth - $netWorthPrevious,
            ...$current,
            'previous' => $before,
            'deltas_bp' => $before === null ? null : [
                'income' => Money::ofCents($current['income_cents'] - $before['income_cents'])->ratioBasisPoints($before['income_cents']),
                'expense' => Money::ofCents($current['expense_cents'] - $before['expense_cents'])->ratioBasisPoints($before['expense_cents']),
                'savings' => Money::ofCents($current['savings_cents'] - $before['savings_cents'])->ratioBasisPoints(abs($before['savings_cents'])),
            ],
            'uncategorized' => $this->spending->uncategorizedExpenses($userId, $period->start_date, $period->effectiveEndDate()),
            'by_category' => $this->byCategory($period),
            'history' => $this->history($period),
            'budgets' => [
                'top' => array_slice($budgetRows, 0, 5),
                'totals' => $this->budgets->totals($budgetRows),
            ],
            'upcoming' => $this->upcoming($userId),
            'recent_transactions' => TransactionResource::collection(
                Transaction::query()->ownedBy($userId)
                    ->with(TransactionResource::RELATIONS)
                    ->orderByDesc('date')->orderByDesc('created_at')
                    ->limit(5)
                    ->get()
            )->resolve($request),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function byCategory(Period $period): array
    {
        $raw = $this->spending->ownSpendingByCategory($period->user_id, $period->start_date, $period->effectiveEndDate());
        $categories = Category::query()->ownedBy($period->user_id)->with('parent')->get()->keyBy('id');
        $total = array_sum($raw);
        $groups = [];

        foreach ($raw as $categoryId => $cents) {
            $category = $categories->get($categoryId);
            $topLevel = $category === null ? null : ($category->parent ?? $category);
            $key = $topLevel->id ?? SpendingQuery::UNCATEGORIZED;

            $groups[$key] ??= [
                'category_id' => $topLevel?->id,
                'name' => $topLevel->name ?? 'Sin categoría',
                'icon' => $topLevel->icon ?? 'circle-help',
                'color' => $topLevel?->color,
                'amount_cents' => 0,
                'percent_bp' => 0,
                'children' => [],
            ];
            $groups[$key]['amount_cents'] += $cents;

            if ($category !== null && $category->parent_id !== null) {
                $groups[$key]['children'][] = [
                    'category' => CategorySummary::of($category),
                    'amount_cents' => $cents,
                ];
            }
        }

        foreach ($groups as &$group) {
            $group['percent_bp'] = Money::ofCents($group['amount_cents'])->ratioBasisPoints($total) ?? 0;
            usort($group['children'], fn (array $left, array $right) => $right['amount_cents'] <=> $left['amount_cents']);
        }
        unset($group);

        $groups = array_values(array_filter($groups, fn (array $group) => $group['amount_cents'] !== 0));
        usort($groups, fn (array $left, array $right) => $right['amount_cents'] <=> $left['amount_cents']);

        return $groups;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function history(Period $period): array
    {
        $today = SpanishCalendar::today();

        $history = [];
        foreach ($this->periods->lastPeriods($period, 12) as $each) {
            $kpis = $this->kpis($each);

            $history[] = [
                'period_id' => $each->id,
                'label' => PeriodPresenter::shortName($each),
                'name' => PeriodPresenter::name($each),
                'start_date' => $each->start_date->toDateString(),
                'end_date' => $each->end_date?->toDateString(),
                'income_cents' => $kpis['income_cents'],
                'expense_cents' => $kpis['expense_cents'],
                'net_worth_cents' => $this->netWorth->at($each->user_id, $each->effectiveEndDate()->min($today)),
            ];
        }

        return $history;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function upcoming(string $userId, int $days = 7): array
    {
        return array_map(fn (array $item) => [
            'rule_id' => $item['rule']->id,
            'name' => $item['rule']->displayName(),
            'date' => $item['date']->toDateString(),
            'amount_cents' => $item['rule']->amount_cents,
            'account_id' => $item['rule']->account_id,
            'category' => CategorySummary::of($item['rule']->category),
            'is_subscription' => $item['rule']->is_subscription,
            'mode' => $item['rule']->mode->value,
        ], $this->recurring->upcoming($userId, $days));
    }
}
