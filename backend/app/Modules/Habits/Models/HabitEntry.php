<?php

namespace App\Modules\Habits\Models;

use App\Modules\Habits\Domain\Enums\EntrySource;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $habit_id
 * @property CarbonImmutable $date
 * @property float $value
 * @property string|null $note
 * @property EntrySource $source
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Habit $habit
 */
class HabitEntry extends Model
{
    use HasUuids;

    protected $table = 'habits.habit_entries';

    protected $guarded = ['id'];

    protected $attributes = [
        'source' => 'manual',
    ];

    protected function casts(): array
    {
        return [
            'date' => 'immutable_date',
            'value' => 'float',
            'source' => EntrySource::class,
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
