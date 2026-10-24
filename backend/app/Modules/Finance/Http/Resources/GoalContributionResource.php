<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Models\GoalContribution;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin GoalContribution
 */
final class GoalContributionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var GoalContribution $contribution */
        $contribution = $this->resource;

        return [
            'id' => $contribution->id,
            'goal_id' => $contribution->goal_id,
            'amount_cents' => $contribution->amount_cents,
            'date' => $contribution->date->toDateString(),
            'note' => $contribution->note,
            'transaction_id' => $contribution->transaction_id,
            'created_at' => $contribution->created_at?->toIso8601String(),
        ];
    }
}
