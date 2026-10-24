<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\PeriodPresenter;
use App\Modules\Finance\Http\Resources\PeriodResource;
use App\Modules\Finance\Queries\DashboardQuery;
use App\Modules\Finance\Queries\NetWorthQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class SummaryController extends FinanceController
{
    public function __invoke(Request $request, PeriodService $periods, DashboardQuery $dashboard, NetWorthQuery $netWorth, BudgetService $budgets): JsonResponse
    {
        $user = $this->user($request);
        $period = $periods->current($user);
        $kpis = $dashboard->kpis($period);
        $budgetTotals = $budgets->totals($budgets->overview($period));

        return response()->json(['data' => [
            'period' => PeriodResource::present($period),
            'spent_cents' => $kpis['expense_cents'],
            'income_cents' => $kpis['income_cents'],
            'savings_cents' => $kpis['savings_cents'],
            'remaining_days' => PeriodPresenter::remainingDays($period),
            'net_worth_cents' => $netWorth->current($user->id),
            'budget' => $budgetTotals,
            'headline' => 'Gastado este periodo',
        ]]);
    }
}
