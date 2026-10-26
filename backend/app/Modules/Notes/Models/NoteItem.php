<?php

namespace App\Modules\Notes\Models;

use App\Modules\Notes\Models\Concerns\HasPreciseTimestamps;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $note_id
 * @property string|null $product_id
 * @property string $text
 * @property string|null $quantity
 * @property string|null $section_id
 * @property CarbonImmutable|null $checked_at
 * @property int $position
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Note $note
 */
class NoteItem extends Model
{
    use HasPreciseTimestamps, HasUuids;

    protected $table = 'notes.note_items';

    protected $guarded = ['id', 'search'];

    protected $hidden = ['search'];

    protected function casts(): array
    {
        return [
            'position' => 'integer',
            'checked_at' => 'immutable_datetime',
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
