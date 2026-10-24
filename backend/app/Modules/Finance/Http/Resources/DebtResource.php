<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Domain\Services\DebtService;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Models\Debt;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Debt
 */
final class DebtResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Debt $debt */
        $debt = $this->resource;
        $debt->loadMissing(['contact', 'recurringRule']);
        $paid = $debt->paidCents();

        return [
            'id' => $debt->id,
            'name' => $debt->name,
            'direction' => $debt->direction->value,
            'contact_id' => $debt->contact_id,
            'contact' => $debt->contact === null ? null : ['id' => $debt->contact->id, 'name' => $debt->contact->name],
            'principal_cents' => $debt->principal_cents,
            'paid_cents' => $paid,
            'pending_cents' => $debt->pendingCents(),
            'progress_bp' => min(10_000, max(0, Money::ofCents($paid)->ratioBasisPoints($debt->principal_cents) ?? 0)),
            'start_date' => $debt->start_date->toDateString(),
            'due_date' => $debt->due_date?->toDateString(),
            'installment_cents' => $debt->installment_cents,
            'installments_count' => $debt->installments_count,
            'installments_paid' => $debt->payments()->whereNull('deleted_at')->count(),
            'recurring_rule_id' => $debt->recurring_rule_id,
            'next_payment_date' => app(DebtService::class)->nextPaymentDate($debt)?->toDateString(),
            'notes' => $debt->notes,
            'closed' => $debt->closed_at !== null,
            'closed_at' => $debt->closed_at?->toIso8601String(),
            'created_at' => $debt->created_at?->toIso8601String(),
            'updated_at' => $debt->updated_at?->toIso8601String(),
        ];
    }
}
