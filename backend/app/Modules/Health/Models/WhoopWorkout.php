<?php

namespace App\Modules\Health\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * A workout WHOOP detected or the member logged, with its strain and heart rate zones.
 *
 * @property string $id
 * @property string $user_id
 * @property string $whoop_id
 * @property CarbonImmutable $starts_at
 * @property CarbonImmutable $ends_at
 * @property CarbonImmutable $day
 * @property string|null $sport_name
 * @property string $score_state
 * @property string|null $strain
 * @property string|null $kilojoule
 * @property int|null $average_heart_rate
 * @property int|null $max_heart_rate
 * @property string|null $distance_meter
 * @property array<string, int>|null $zone_durations
 * @property array<string, mixed> $payload
 */
class WhoopWorkout extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'health.whoop_workouts';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'starts_at' => 'immutable_datetime',
            'ends_at' => 'immutable_datetime',
            'day' => 'immutable_date',
            'strain' => 'decimal:2',
            'kilojoule' => 'decimal:2',
            'average_heart_rate' => 'integer',
            'max_heart_rate' => 'integer',
            'distance_meter' => 'decimal:2',
            'zone_durations' => 'array',
            'payload' => 'array',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }
}
