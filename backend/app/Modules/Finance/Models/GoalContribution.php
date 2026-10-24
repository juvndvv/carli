<?php

namespace App\Modules\Finance\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $goal_id
 * @property int $amount_cents
 * @property CarbonImmutable $date
 * @property string|null $transaction_id
 * @property string|null $note
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class GoalContribution extends Model
{
    use HasUuids;

    protected $table = 'finance.goal_contributions';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'amount_cents' => 'integer',
            'date' => 'immutable_date',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<SavingsGoal, $this>
     */
    public function goal(): BelongsTo
    {
        return $this->belongsTo(SavingsGoal::class, 'goal_id')->withoutGlobalScopes();
    }
}
