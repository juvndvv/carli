<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Http\Requests\ConfirmRecurringRuleRequest;
use App\Modules\Finance\Http\Requests\StoreRecurringRuleRequest;
use App\Modules\Finance\Http\Requests\UpdateRecurringRuleRequest;
use App\Modules\Finance\Http\Resources\RecurringRuleResource;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\RecurringRule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class RecurringRuleController extends FinanceController
{
    public function __construct(private readonly RecurringService $recurring) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $rules = RecurringRule::query()->ownedBy($this->user($request))
            ->with(['account', 'category.parent', 'debt'])
            ->when($request->boolean('subscriptions'), fn ($query) => $query->where('is_subscription', true))
            ->when(! $request->boolean('include_cancelled'), fn ($query) => $query->whereNull('cancelled_at'))
            ->orderByRaw('next_occurrence IS NULL, next_occurrence')
            ->orderBy('payee')
            ->get();

        $active = $rules->filter(fn (RecurringRule $rule) => $rule->isActive());
        $subscriptions = $active->filter(fn (RecurringRule $rule) => $rule->is_subscription);

        return RecurringRuleResource::collection($rules)->additional(['meta' => [
            'active_count' => $active->count(),
            'monthly_total_cents' => $active->sum(fn (RecurringRule $rule) => RecurringService::monthlyCostCents($rule)),
            'subscriptions' => [
                'count' => $subscriptions->count(),
                'monthly_cents' => $subscriptions->sum(fn (RecurringRule $rule) => RecurringService::monthlyCostCents($rule)),
                'yearly_cents' => $subscriptions->sum(fn (RecurringRule $rule) => RecurringService::yearlyCostCents($rule)),
            ],
        ]]);
    }

    public function store(StoreRecurringRuleRequest $request): JsonResponse
    {
        $rule = $this->recurring->create($request->financeUser(), $request->validated());

        return (new RecurringRuleResource($rule))->response()->setStatusCode(201);
    }

    public function show(RecurringRule $recurringRule): RecurringRuleResource
    {
        $this->authorizeOwner('view', $recurringRule);

        return new RecurringRuleResource($recurringRule);
    }

    public function update(UpdateRecurringRuleRequest $request, RecurringRule $recurringRule): RecurringRuleResource
    {
        $this->authorizeOwner('update', $recurringRule);

        return new RecurringRuleResource($this->recurring->update($recurringRule, $request->validated()));
    }

    public function destroy(RecurringRule $recurringRule): Response
    {
        $this->authorizeOwner('delete', $recurringRule);
        $this->recurring->delete($recurringRule);

        return response()->noContent();
    }

    public function confirm(ConfirmRecurringRuleRequest $request, RecurringRule $recurringRule): JsonResponse
    {
        $this->authorizeOwner('update', $recurringRule);

        /** @var array{amount_cents?: int|null, date?: string|null, update_rule_amount?: bool|null} $data */
        $data = $request->validated();
        $result = $this->recurring->confirm($recurringRule, $data);

        return response()->json(['data' => [
            'transaction' => (new TransactionResource($result['transaction']))->resolve($request),
            'rule' => (new RecurringRuleResource($recurringRule->refresh()))->resolve($request),
            'price_changed' => $result['price_changed'],
            'previous_amount_cents' => $result['previous_amount_cents'],
        ]]);
    }
}
