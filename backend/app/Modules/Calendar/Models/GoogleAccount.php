<?php

namespace App\Modules\Calendar\Models;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A Google account linked through OAuth (read-only Calendar scope). Tokens are stored encrypted.
 *
 * @property string $id
 * @property string $user_id
 * @property string $email
 * @property string|null $access_token
 * @property string $refresh_token
 * @property CarbonImmutable|null $token_expires_at
 * @property string $status
 * @property string|null $last_error
 * @property CarbonImmutable|null $synced_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read User $user
 * @property-read Collection<int, GoogleCalendar> $calendars
 */
class GoogleAccount extends Model
{
    use HasUuids;

    public const string ACTIVE = 'active';

    public const string RECONNECT = 'reconnect';

    protected $table = 'calendar.google_accounts';

    protected $guarded = ['id'];

    protected $hidden = ['access_token', 'refresh_token'];

    protected function casts(): array
    {
        return [
            'access_token' => 'encrypted',
            'refresh_token' => 'encrypted',
            'token_expires_at' => 'immutable_datetime',
            'synced_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return HasMany<GoogleCalendar, $this>
     */
    public function calendars(): HasMany
    {
        return $this->hasMany(GoogleCalendar::class, 'account_id')->orderByDesc('primary')->orderBy('sort')->orderBy('name');
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeOwnedBy(Builder $query, User|string $user): void
    {
        $query->where('user_id', $user instanceof User ? $user->id : $user);
    }

    public function needsReconnect(): bool
    {
        return $this->status === self::RECONNECT;
    }
}
