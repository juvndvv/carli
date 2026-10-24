<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Models\SharedExpenseShare;
use App\Modules\Finance\Models\Tag;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Models\TransactionSplit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Transaction
 */
final class TransactionResource extends JsonResource
{
    public const array RELATIONS = ['account', 'category.parent', 'tags', 'splits.category.parent', 'shares.contact', 'transferLegs'];

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Transaction $transaction */
        $transaction = $this->resource;
        $transaction->loadMissing(self::RELATIONS);
        $counterpart = $transaction->transfer_group_id === null
            ? null
            : $transaction->transferLegs->first(fn (Transaction $leg) => $leg->id !== $transaction->id);

        return [
            'id' => $transaction->id,
            'account_id' => $transaction->account_id,
            'account' => [
                'id' => $transaction->account->id,
                'name' => $transaction->account->name,
                'type' => $transaction->account->type->value,
            ],
            'kind' => $transaction->kind->value,
            'amount_cents' => $transaction->amount_cents,
            'own_amount_cents' => $transaction->ownAmountCents(),
            'date' => $transaction->date->toDateString(),
            'category_id' => $transaction->category_id,
            'category' => CategorySummary::of($transaction->category),
            'payee' => $transaction->payee,
            'description' => $transaction->description,
            'notes' => $transaction->notes,
            'tags' => $transaction->tags->map(fn (Tag $tag) => $tag->name)->values()->all(),
            'status' => $transaction->status->value,
            'transfer_group_id' => $transaction->transfer_group_id,
            'transfer_account_id' => $counterpart?->account_id,
            'recurring_rule_id' => $transaction->recurring_rule_id,
            'debt_id' => $transaction->debt_id,
            'splits' => $transaction->splits->map(fn (TransactionSplit $split) => [
                'id' => $split->id,
                'category_id' => $split->category_id,
                'category' => CategorySummary::of($split->category),
                'amount_cents' => $split->amount_cents,
            ])->values()->all(),
            'shares' => $transaction->shares->map(fn (SharedExpenseShare $share) => [
                'id' => $share->id,
                'contact_id' => $share->contact_id,
                'name' => $share->contact->name,
                'amount_cents' => $share->amount_cents,
                'mode' => $share->mode->value,
                'basis_points' => $share->basis_points,
                'include_self' => $share->include_self,
                'settled' => $share->settled_at !== null,
                'settled_at' => $share->settled_at?->toIso8601String(),
                'settlement_transaction_id' => $share->settlement_transaction_id,
            ])->values()->all(),
            'deleted' => $transaction->deleted_at !== null,
            'created_at' => $transaction->created_at?->toIso8601String(),
            'updated_at' => $transaction->updated_at?->toIso8601String(),
        ];
    }
}
