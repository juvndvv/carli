<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string $name
 * @property string|null $color
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property int|null $transactions_count
 */
class Tag extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.tags';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsToMany<Transaction, $this>
     */
    public function transactions(): BelongsToMany
    {
        return $this->belongsToMany(Transaction::class, 'finance.transaction_tag');
    }
}
