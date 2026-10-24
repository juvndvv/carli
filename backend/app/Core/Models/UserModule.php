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
 * @property bool $enabled
 * @property array<string, mixed> $settings
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class UserModule extends Model
{
    use HasUuids;

    protected $table = 'user_modules';

    protected $fillable = ['user_id', 'module_id', 'enabled', 'settings'];

    protected $attributes = [
        'enabled' => true,
        'settings' => '{}',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'enabled' => 'boolean',
            'settings' => 'array',
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
