<?php

namespace App\Core\Models;

use App\Core\Push\ApnsEnvironment;
use App\Models\User;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * @property string $id
 * @property string $user_id
 * @property string $token
 * @property ApnsEnvironment $environment
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class PushDevice extends Model
{
    use HasUuids;

    protected $table = 'push_devices';

    protected $fillable = ['user_id', 'token', 'environment'];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'environment' => ApnsEnvironment::class,
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
