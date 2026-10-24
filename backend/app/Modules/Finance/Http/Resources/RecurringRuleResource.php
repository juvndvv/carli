<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin RecurringRule
 */
final class RecurringRuleResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var RecurringRule $rule */
        $rule = $this->resource;
        $rule->loadMissing(['account', 'category.parent', 'debt']);

        $pending = Transaction::query()->ownedBy($rule->user_id)
            ->where('recurring_rule_id', $rule->id)
            ->where('status', TransactionStatus::Pending->value)
            ->orderBy('date')
            ->first(['id', 'date', 'amount_cents']);

        return [
            'id' => $rule->id,
            'name' => $rule->displayName(),
            'account_id' => $rule->account_id,
            'account' => ['id' => $rule->account->id, 'name' => $rule->account->name, 'type' => $rule->account->type->value],
            'category_id' => $rule->category_id,
            'category' => CategorySummary::of($rule->category),
            'kind' => $rule->kind->value,
            'amount_cents' => $rule->amount_cents,
            'payee' => $rule->payee,
            'description' => $rule->description,
            'frequency' => $rule->frequency->value,
            'interval' => $rule->interval,
            'day_of_month' => $rule->day_of_month,
            'start_date' => $rule->start_date->toDateString(),
            'end_date' => $rule->end_date?->toDateString(),
            'next_occurrence' => $rule->next_occurrence?->toDateString(),
            'mode' => $rule->mode->value,
            'remind_days_before' => $rule->remind_days_before,
            'is_subscription' => $rule->is_subscription,
            'cancelled' => $rule->cancelled_at !== null,
            'cancelled_at' => $rule->cancelled_at?->toIso8601String(),
            'active' => $rule->isActive(),
            'monthly_cost_cents' => RecurringService::monthlyCostCents($rule),
            'yearly_cost_cents' => RecurringService::yearlyCostCents($rule),
            'pending_transaction' => $pending === null ? null : [
                'id' => $pending->id,
                'date' => $pending->date->toDateString(),
                'amount_cents' => $pending->amount_cents,
            ],
            'debt_id' => $rule->debt?->id,
            'created_at' => $rule->created_at?->toIso8601String(),
            'updated_at' => $rule->updated_at?->toIso8601String(),
        ];
    }
}
