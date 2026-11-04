<?php

namespace App\Modules\Health\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * A WHOOP physiological cycle: WHOOP's day, with its strain and steps.
 *
 * @property string $id
 * @property string $user_id
 * @property int $whoop_id
 * @property CarbonImmutable $starts_at
 * @property CarbonImmutable|null $ends_at
 * @property CarbonImmutable $day
 * @property string $score_state
 * @property string|null $strain
 * @property string|null $kilojoule
 * @property int|null $average_heart_rate
 * @property int|null $max_heart_rate
 * @property int|null $step_count
 * @property array<string, mixed> $payload
 */
class WhoopCycle extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'health.whoop_cycles';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'whoop_id' => 'integer',
            'starts_at' => 'immutable_datetime',
            'ends_at' => 'immutable_datetime',
            'day' => 'immutable_date',
            'strain' => 'decimal:2',
            'kilojoule' => 'decimal:2',
            'average_heart_rate' => 'integer',
            'max_heart_rate' => 'integer',
            'step_count' => 'integer',
            'payload' => 'array',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }
}
