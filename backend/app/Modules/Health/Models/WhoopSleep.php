<?php

namespace App\Modules\Health\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * A night's sleep or a nap as WHOOP scored it. Stage times are in milliseconds.
 *
 * @property string $id
 * @property string $user_id
 * @property string $whoop_id
 * @property int|null $cycle_whoop_id
 * @property CarbonImmutable $starts_at
 * @property CarbonImmutable $ends_at
 * @property CarbonImmutable $day
 * @property bool $nap
 * @property string $score_state
 * @property int|null $in_bed_milli
 * @property int|null $awake_milli
 * @property int|null $light_milli
 * @property int|null $deep_milli
 * @property int|null $rem_milli
 * @property int|null $disturbances
 * @property string|null $respiratory_rate
 * @property int|null $performance_percentage
 * @property int|null $consistency_percentage
 * @property string|null $efficiency_percentage
 * @property int|null $need_milli
 * @property array<string, mixed> $payload
 */
class WhoopSleep extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'health.whoop_sleeps';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'cycle_whoop_id' => 'integer',
            'starts_at' => 'immutable_datetime',
            'ends_at' => 'immutable_datetime',
            'day' => 'immutable_date',
            'nap' => 'boolean',
            'in_bed_milli' => 'integer',
            'awake_milli' => 'integer',
            'light_milli' => 'integer',
            'deep_milli' => 'integer',
            'rem_milli' => 'integer',
            'disturbances' => 'integer',
            'respiratory_rate' => 'decimal:2',
            'performance_percentage' => 'integer',
            'consistency_percentage' => 'integer',
            'efficiency_percentage' => 'decimal:2',
            'need_milli' => 'integer',
            'payload' => 'array',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    public function asleepMilli(): ?int
    {
        if ($this->light_milli === null || $this->deep_milli === null || $this->rem_milli === null) {
            return null;
        }

        return $this->light_milli + $this->deep_milli + $this->rem_milli;
    }
}
