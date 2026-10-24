<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Http\Requests\CopyBudgetsRequest;
use App\Modules\Finance\Http\Requests\PeriodQueryRequest;
use App\Modules\Finance\Http\Requests\UpsertBudgetsRequest;
use App\Modules\Finance\Http\Resources\PeriodResource;
use App\Modules\Finance\Models\Period;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class BudgetController extends FinanceController
{
    public function __construct(
        private readonly BudgetService $budgets,
        private readonly PeriodService $periods,
    ) {}

    public function index(PeriodQueryRequest $request): JsonResponse
    {
        return $this->overview($this->resolvePeriod($request), $request);
    }

    public function update(UpsertBudgetsRequest $request): JsonResponse
    {
        $period = $this->resolvePeriod($request);

        /** @var list<array{category_id: string, amount_cents: int|null, rollover?: bool|null}> $items */
        $items = array_values($request->validated('budgets'));
        $this->budgets->upsert($period, $items);

        return $this->overview($period, $request);
    }

    public function copy(CopyBudgetsRequest $request): JsonResponse
    {
        $user = $request->financeUser();
        $from = $this->periods->find($user, (string) $request->validated('from_period_id'));
        $to = $this->periods->find($user, (string) $request->validated('to_period_id'));
        abort_if($from === null || $to === null, 404);

        $copied = $this->budgets->copy($from, $to);

        return $this->overview($to, $request, ['copied' => $copied]);
    }

    /**
     * @param  array<string, mixed>  $meta
     */
    private function overview(Period $period, Request $request, array $meta = []): JsonResponse
    {
        $rows = $this->budgets->overview($period);
        $previous = $this->periods->previous($period);

        return response()->json([
            'data' => $rows,
            'meta' => [
                'period' => PeriodResource::present($period),
                'previous_period' => $previous === null ? null : PeriodResource::present($previous),
                'totals' => $this->budgets->totals($rows),
                ...$meta,
            ],
        ]);
    }

    private function resolvePeriod(PeriodQueryRequest|UpsertBudgetsRequest $request): Period
    {
        $user = $request->financeUser();
        $periodId = $request->validated('period_id');

        if (is_string($periodId)) {
            return $this->periods->find($user, $periodId) ?? abort(404);
        }

        return $this->periods->current($user);
    }
}
