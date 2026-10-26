<?php

namespace App\Modules\Notes\Models;

use App\Modules\Notes\Models\Concerns\BelongsToUser;
use App\Modules\Notes\Models\Concerns\HasPreciseTimestamps;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * @property string $id
 * @property string $user_id
 * @property string|null $parent_id
 * @property string $name
 * @property int $position
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class Folder extends Model
{
    use BelongsToUser, HasPreciseTimestamps, HasUuids;

    protected $table = 'notes.note_folders';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'position' => 'integer',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }
}
