<?php

namespace App\Modules\Habits\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $user_id
 * @property string|null $habit_id
 * @property CarbonImmutable $from_date
 * @property CarbonImmutable $to_date
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Habit|null $habit
 */
class HabitBreak extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'habits.habit_breaks';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'from_date' => 'immutable_date',
            'to_date' => 'immutable_date',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Habit, $this>
     */
    public function habit(): BelongsTo
    {
        return $this->belongsTo(Habit::class)->withoutGlobalScopes();
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeGlobal(Builder $query): void
    {
        $query->whereNull('habit_id');
    }

    public function covers(CarbonImmutable $day): bool
    {
        return $day->betweenIncluded($this->from_date, $this->to_date);
    }
}
