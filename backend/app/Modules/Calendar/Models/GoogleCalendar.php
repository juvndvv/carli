<?php

namespace App\Modules\Calendar\Models;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * One calendar of a linked account. Only selected calendars are synced and shown.
 *
 * @property string $id
 * @property string $user_id
 * @property string $account_id
 * @property string $google_id
 * @property string $name
 * @property string|null $color
 * @property bool $primary
 * @property bool $selected
 * @property int $sort
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read GoogleAccount $account
 */
class GoogleCalendar extends Model
{
    use HasUuids;

    protected $table = 'calendar.google_calendars';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'primary' => 'boolean',
            'selected' => 'boolean',
            'sort' => 'integer',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<GoogleAccount, $this>
     */
    public function account(): BelongsTo
    {
        return $this->belongsTo(GoogleAccount::class, 'account_id');
    }

    /**
     * @return HasMany<CalendarEvent, $this>
     */
    public function events(): HasMany
    {
        return $this->hasMany(CalendarEvent::class, 'calendar_id');
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeOwnedBy(Builder $query, User|string $user): void
    {
        $query->where('user_id', $user instanceof User ? $user->id : $user);
    }
}
