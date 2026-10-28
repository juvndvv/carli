<?php

namespace App\Core\Models;

use App\Core\Push\ApnsEnvironment;
use App\Core\Push\PushDeviceKind;
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
 * @property PushDeviceKind $kind
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class PushDevice extends Model
{
    use HasUuids;

    /** @var array<string, string> */
    protected $attributes = ['kind' => 'app'];

    protected $table = 'push_devices';

    protected $fillable = ['user_id', 'token', 'environment', 'kind'];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'environment' => ApnsEnvironment::class,
            'kind' => PushDeviceKind::class,
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
