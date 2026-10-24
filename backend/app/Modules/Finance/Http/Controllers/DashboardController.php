<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Http\Requests\PeriodQueryRequest;
use App\Modules\Finance\Queries\DashboardQuery;
use Illuminate\Http\JsonResponse;

final class DashboardController extends FinanceController
{
    public function __invoke(PeriodQueryRequest $request, PeriodService $periods, DashboardQuery $dashboard): JsonResponse
    {
        $user = $request->financeUser();
        $current = $periods->current($user);
        $periodId = $request->validated('period_id');
        $period = is_string($periodId) ? ($periods->find($user, $periodId) ?? $current) : $current;

        return response()->json(['data' => $dashboard->build($period, $request)]);
    }
}
