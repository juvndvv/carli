<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Domain\Enums\AccountType;
use App\Modules\Finance\Models\Account;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Account
 */
final class AccountResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Account $account */
        $account = $this->resource;
        $balance = $account->balanceCents();
        $pending = $account->pendingCents();
        $isCreditCard = $account->type === AccountType::CreditCard;
        $connection = $account->isBankLinked() ? $account->bankConnection : null;

        return [
            'id' => $account->id,
            'name' => $account->name,
            'type' => $account->type->value,
            'initial_balance_cents' => $account->initial_balance_cents,
            'initial_balance_date' => $account->initial_balance_date?->toDateString(),
            'balance_cents' => $balance,
            'cleared_balance_cents' => $balance - $pending,
            'pending_cents' => $pending,
            'credit_limit_cents' => $account->credit_limit_cents,
            'statement_day' => $account->statement_day,
            'payment_day' => $account->payment_day,
            'used_credit_cents' => $isCreditCard ? max(0, -$balance) : null,
            'available_credit_cents' => $isCreditCard && $account->credit_limit_cents !== null ? $account->credit_limit_cents + $balance : null,
            'color' => $account->color,
            'icon' => $account->icon,
            'include_in_net_worth' => $account->include_in_net_worth,
            'ownership_percent' => $account->ownership_percent,
            'own_balance_cents' => $account->ownShareOf($balance),
            'sort_order' => $account->sort_order,
            'bank' => $connection === null ? null : [
                'connection_id' => $connection->id,
                'aspsp_name' => $connection->aspsp_name,
                'status' => $connection->effectiveStatus()->value,
                'sync_from_date' => $account->sync_from_date?->toDateString(),
                'last_synced_at' => $connection->last_synced_at?->toIso8601String(),
                'balance_cents' => $account->bank_balance_cents,
                'balance_at' => $account->bank_balance_at?->toIso8601String(),
                'difference_cents' => $account->bank_balance_cents === null ? null : $account->bank_balance_cents - ($balance - $pending),
            ],
            'archived' => $account->archived_at !== null,
            'archived_at' => $account->archived_at?->toIso8601String(),
            'created_at' => $account->created_at?->toIso8601String(),
            'updated_at' => $account->updated_at?->toIso8601String(),
        ];
    }
}
