<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string $name
 * @property int $target_cents
 * @property CarbonImmutable|null $target_date
 * @property string|null $account_id
 * @property string|null $icon
 * @property string|null $color
 * @property int $notified_milestone
 * @property CarbonImmutable|null $achieved_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Account|null $account
 */
class SavingsGoal extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.savings_goals';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'notified_milestone' => 0,
    ];

    protected function casts(): array
    {
        return [
            'target_cents' => 'integer',
            'target_date' => 'immutable_date',
            'notified_milestone' => 'integer',
            'achieved_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Account, $this>
     */
    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class)->withoutGlobalScopes();
    }

    /**
     * @return HasMany<GoalContribution, $this>
     */
    public function contributions(): HasMany
    {
        return $this->hasMany(GoalContribution::class, 'goal_id')->orderByDesc('date')->orderByDesc('id');
    }
}
