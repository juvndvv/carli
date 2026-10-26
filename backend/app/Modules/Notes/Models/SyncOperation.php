<?php

namespace App\Modules\Notes\Models;

use App\Modules\Notes\Models\Concerns\BelongsToUser;
use App\Modules\Notes\Models\Concerns\HasPreciseTimestamps;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Model;

/**
 * @property string $id
 * @property string $user_id
 * @property string $type
 * @property CarbonImmutable $processed_at
 * @property string $status
 */
class SyncOperation extends Model
{
    use BelongsToUser, HasPreciseTimestamps;

    public $timestamps = false;

    public $incrementing = false;

    protected $keyType = 'string';

    protected $table = 'notes.sync_operations';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'processed_at' => 'immutable_datetime',
        ];
    }
}
