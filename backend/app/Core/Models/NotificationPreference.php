<?php

namespace App\Core\Models;

use App\Models\User;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * @property string $id
 * @property string $user_id
 * @property string $module_id
 * @property string $type
 * @property bool $push
 * @property bool $in_app
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class NotificationPreference extends Model
{
    use HasUuids;

    protected $table = 'notification_preferences';

    protected $fillable = ['user_id', 'module_id', 'type', 'push', 'in_app'];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'push' => 'boolean',
            'in_app' => 'boolean',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
