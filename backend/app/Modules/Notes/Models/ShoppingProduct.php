<?php

namespace App\Modules\Notes\Models;

use App\Modules\Notes\Domain\Enums\RestockMode;
use App\Modules\Notes\Models\Concerns\BelongsToUser;
use App\Modules\Notes\Models\Concerns\HasPreciseTimestamps;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $user_id
 * @property string $note_id
 * @property string $name
 * @property string $name_normalized
 * @property string|null $section_id
 * @property string|null $default_quantity
 * @property RestockMode $restock_mode
 * @property int|null $restock_interval_days
 * @property CarbonImmutable|null $last_bought_at
 * @property int $times_bought
 * @property string|null $restocked_for
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Note $note
 */
class ShoppingProduct extends Model
{
    use BelongsToUser, HasPreciseTimestamps, HasUuids;

    protected $table = 'notes.shopping_products';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'restock_mode' => RestockMode::class,
            'restock_interval_days' => 'integer',
            'times_bought' => 'integer',
            'last_bought_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Note, $this>
     */
    public function note(): BelongsTo
    {
        return $this->belongsTo(Note::class);
    }
}
