<?php

namespace App\Modules\Calendar\Models;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A Google event instance copied from a selected calendar. Read-only: Google stays the owner.
 *
 * @property string $id
 * @property string $user_id
 * @property string $calendar_id
 * @property string $google_id
 * @property string $title
 * @property string|null $location
 * @property string|null $description
 * @property bool $all_day
 * @property CarbonImmutable|null $starts_at
 * @property CarbonImmutable|null $ends_at
 * @property CarbonImmutable $start_date
 * @property CarbonImmutable $end_date
 * @property string|null $html_link
 * @property string|null $meet_link
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read GoogleCalendar $calendar
 */
class CalendarEvent extends Model
{
    use HasUuids;

    protected $table = 'calendar.events';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'all_day' => 'boolean',
            'starts_at' => 'immutable_datetime',
            'ends_at' => 'immutable_datetime',
            'start_date' => 'immutable_date',
            'end_date' => 'immutable_date',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<GoogleCalendar, $this>
     */
    public function calendar(): BelongsTo
    {
        return $this->belongsTo(GoogleCalendar::class, 'calendar_id');
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeOwnedBy(Builder $query, User|string $user): void
    {
        $query->where($query->qualifyColumn('user_id'), $user instanceof User ? $user->id : $user);
    }

    /**
     * Events touching [from, to]: all-day end dates are exclusive, timed ones end on their last day.
     *
     * @param  Builder<static>  $query
     */
    public function scopeOverlapping(Builder $query, CarbonImmutable $from, CarbonImmutable $to): void
    {
        $query->where($query->qualifyColumn('start_date'), '<=', $to->toDateString())
            ->where(fn (Builder $q) => $q
                ->where(fn (Builder $allDay) => $allDay->where($q->qualifyColumn('all_day'), true)->where($q->qualifyColumn('end_date'), '>', $from->toDateString()))
                ->orWhere(fn (Builder $timed) => $timed->where($q->qualifyColumn('all_day'), false)->where($q->qualifyColumn('end_date'), '>=', $from->toDateString())));
    }
}
