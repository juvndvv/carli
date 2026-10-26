<?php

namespace App\Modules\Notes\Models;

use App\Modules\Notes\Domain\Enums\CheckedBehavior;
use App\Modules\Notes\Domain\Enums\NoteType;
use App\Modules\Notes\Models\Concerns\BelongsToUser;
use App\Modules\Notes\Models\Concerns\HasPreciseTimestamps;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string|null $folder_id
 * @property NoteType $type
 * @property string|null $title
 * @property string|null $body
 * @property CarbonImmutable|null $pinned_at
 * @property CarbonImmutable|null $archived_at
 * @property CarbonImmutable|null $deleted_at
 * @property CheckedBehavior $checked_behavior
 * @property bool $is_primary
 * @property int $sort
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Collection<int, NoteItem> $items
 * @property-read Folder|null $folder
 */
class Note extends Model
{
    use BelongsToUser, HasPreciseTimestamps, HasUuids;

    protected $table = 'notes.notes';

    protected $guarded = ['id', 'user_id', 'search'];

    protected $hidden = ['search'];

    protected function casts(): array
    {
        return [
            'type' => NoteType::class,
            'checked_behavior' => CheckedBehavior::class,
            'is_primary' => 'boolean',
            'sort' => 'integer',
            'pinned_at' => 'immutable_datetime',
            'archived_at' => 'immutable_datetime',
            'deleted_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return HasMany<NoteItem, $this>
     */
    public function items(): HasMany
    {
        return $this->hasMany(NoteItem::class)->orderBy('position')->orderBy('created_at');
    }

    /**
     * @return BelongsTo<Folder, $this>
     */
    public function folder(): BelongsTo
    {
        return $this->belongsTo(Folder::class);
    }
}
