<?php

namespace App\Modules\Habits\Models;

use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string $name
 * @property string $icon
 * @property HabitKind $kind
 * @property string|null $unit
 * @property bool $show_in_tasks
 * @property int $sort
 * @property CarbonImmutable $start_date
 * @property string|null $preferred_time
 * @property CarbonImmutable|null $paused_at
 * @property CarbonImmutable|null $archived_at
 * @property string|null $converted_from_template_id
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Collection<int, HabitGoal> $goals
 * @property-read Collection<int, HabitEntry> $entries
 * @property-read Collection<int, HabitBreak> $breaks
 */
class Habit extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'habits.habits';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'show_in_tasks' => true,
        'sort' => 0,
    ];

    protected function casts(): array
    {
        return [
            'kind' => HabitKind::class,
            'show_in_tasks' => 'boolean',
            'sort' => 'integer',
            'start_date' => 'immutable_date',
            'paused_at' => 'immutable_datetime',
            'archived_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return HasMany<HabitGoal, $this>
     */
    public function goals(): HasMany
    {
        return $this->hasMany(HabitGoal::class)->orderBy('valid_from');
    }

    /**
     * @return HasMany<HabitEntry, $this>
     */
    public function entries(): HasMany
    {
        return $this->hasMany(HabitEntry::class)->orderBy('date');
    }

    /**
     * @return HasMany<HabitBreak, $this>
     */
    public function breaks(): HasMany
    {
        return $this->hasMany(HabitBreak::class)->withoutGlobalScopes();
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeActive(Builder $query): void
    {
        $query->whereNull('paused_at')->whereNull('archived_at');
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeOrdered(Builder $query): void
    {
        $query->orderBy('sort')->orderByRaw('preferred_time ASC NULLS LAST')->orderBy('created_at')->orderBy('id');
    }

    public function isActive(): bool
    {
        return $this->paused_at === null && $this->archived_at === null;
    }

    public function stoppedOn(): ?CarbonImmutable
    {
        $moments = array_filter([$this->paused_at, $this->archived_at]);

        return $moments === [] ? null : HabitCalendar::localDay(min($moments));
    }

    public function currentGoal(): HabitGoal
    {
        $goal = $this->goals->last();

        if (! $goal instanceof HabitGoal) {
            throw new \LogicException("Habit [{$this->id}] has no goal.");
        }

        return $goal;
    }
}
