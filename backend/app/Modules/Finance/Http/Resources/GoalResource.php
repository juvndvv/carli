<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Domain\Services\GoalService;
use App\Modules\Finance\Models\SavingsGoal;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin SavingsGoal
 */
final class GoalResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var SavingsGoal $goal */
        $goal = $this->resource;
        $goal->loadMissing('account');
        $progress = app(GoalService::class)->progress($goal);

        return [
            'id' => $goal->id,
            'name' => $goal->name,
            'target_cents' => $goal->target_cents,
            'target_date' => $goal->target_date?->toDateString(),
            'account_id' => $goal->account_id,
            'account' => $goal->account === null ? null : ['id' => $goal->account->id, 'name' => $goal->account->name, 'type' => $goal->account->type->value],
            'icon' => $goal->icon,
            'color' => $goal->color,
            'achieved' => $goal->achieved_at !== null,
            'achieved_at' => $goal->achieved_at?->toIso8601String(),
            ...$progress,
            'contributions_count' => $goal->account_id === null ? $goal->contributions()->count() : 0,
            'created_at' => $goal->created_at?->toIso8601String(),
            'updated_at' => $goal->updated_at?->toIso8601String(),
        ];
    }
}
