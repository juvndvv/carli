<?php

namespace App\Modules\Habits\Models;

use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Models\Casts\SmallIntArray;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $habit_id
 * @property CarbonImmutable $valid_from
 * @property GoalPeriod $period
 * @property float $target
 * @property list<int>|null $days_of_week
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Habit $habit
 */
class HabitGoal extends Model
{
    use HasUuids;

    protected $table = 'habits.habit_goals';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'valid_from' => 'immutable_date',
            'period' => GoalPeriod::class,
            'target' => 'float',
            'days_of_week' => SmallIntArray::class,
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
}
