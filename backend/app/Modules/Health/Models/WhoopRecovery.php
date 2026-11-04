<?php

namespace App\Modules\Health\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * WHOOP's recovery for a cycle, worked out from the sleep that opens it.
 *
 * @property string $id
 * @property string $user_id
 * @property int $cycle_whoop_id
 * @property string $sleep_whoop_id
 * @property string $score_state
 * @property bool $calibrating
 * @property int|null $recovery_score
 * @property int|null $resting_heart_rate
 * @property string|null $hrv_rmssd_milli
 * @property string|null $spo2_percentage
 * @property string|null $skin_temp_celsius
 * @property array<string, mixed> $payload
 */
class WhoopRecovery extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'health.whoop_recoveries';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'cycle_whoop_id' => 'integer',
            'calibrating' => 'boolean',
            'recovery_score' => 'integer',
            'resting_heart_rate' => 'integer',
            'hrv_rmssd_milli' => 'decimal:3',
            'spo2_percentage' => 'decimal:2',
            'skin_temp_celsius' => 'decimal:2',
            'payload' => 'array',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }
}
