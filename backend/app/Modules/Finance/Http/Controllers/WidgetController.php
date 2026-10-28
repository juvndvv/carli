<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\PeriodPresenter;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Queries\DashboardQuery;
use App\Modules\Finance\Queries\SpendingQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The small payload behind the Lock Screen widgets: the period at a glance, today's spending and the latest expenses.
 */
final class WidgetController extends FinanceController
{
    private const int LATEST = 3;

    public function __invoke(Request $request, PeriodService $periods, DashboardQuery $dashboard, BudgetService $budgets, SpendingQuery $spending): JsonResponse
    {
        $user = $this->user($request);
        $period = $periods->current($user);
        $today = SpanishCalendar::today();
        $budget = $budgets->totals($budgets->overview($period));

        $latest = Transaction::query()->ownedBy($user)
            ->with('category')
            ->where('kind', TransactionKind::Expense->value)
            ->orderByDesc('date')->orderByDesc('created_at')
            ->limit(self::LATEST)
            ->get();

        return response()->json(['data' => [
            'period' => [
                'start_date' => $period->start_date->toDateString(),
                'end_date' => $period->effectiveEndDate()->toDateString(),
                'remaining_days' => PeriodPresenter::remainingDays($period, $today),
                'spent_cents' => $dashboard->kpis($period)['expense_cents'],
                'budgeted_cents' => $budget['budgeted_cents'],
                'budget_remaining_cents' => $budget['remaining_cents'],
                'budget_percent_bp' => $budget['percent_bp'],
            ],
            'today' => [
                'spent_cents' => $spending->ownSpendingTotal($user->id, $today, $today),
                'count' => Transaction::query()->ownedBy($user)
                    ->where('kind', TransactionKind::Expense->value)
                    ->whereDate('date', $today->toDateString())
                    ->count(),
            ],
            'latest' => $latest->map(fn (Transaction $transaction) => [
                'id' => $transaction->id,
                'name' => $transaction->payee ?? $transaction->description ?? $transaction->category?->name ?? 'Gasto',
                'amount_cents' => $transaction->amount_cents,
                'date' => $transaction->date->toDateString(),
            ])->values()->all(),
            'updated_at' => now()->toIso8601String(),
        ]]);
    }
}
