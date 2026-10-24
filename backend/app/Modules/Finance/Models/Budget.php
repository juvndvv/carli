<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $user_id
 * @property string $category_id
 * @property string $period_id
 * @property int $amount_cents
 * @property bool $rollover
 * @property int|null $notified_threshold
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Category $category
 * @property-read Period $period
 */
class Budget extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.budgets';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'rollover' => false,
    ];

    protected function casts(): array
    {
        return [
            'amount_cents' => 'integer',
            'rollover' => 'boolean',
            'notified_threshold' => 'integer',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Category, $this>
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class)->withoutGlobalScopes();
    }

    /**
     * @return BelongsTo<Period, $this>
     */
    public function period(): BelongsTo
    {
        return $this->belongsTo(Period::class)->withoutGlobalScopes();
    }
}
