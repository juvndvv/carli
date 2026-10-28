<?php

namespace App\Modules\Health\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * @property string $id
 * @property string $user_id
 * @property CarbonImmutable $measured_at
 * @property string $weight_kg
 * @property string $source
 * @property string|null $bmi
 * @property string|null $fat_percent
 * @property string|null $muscle_percent
 * @property string|null $water_percent
 * @property int|null $visceral_or_bone
 * @property int|null $basal_kcal
 * @property list<int>|null $impedances
 * @property string|null $frames
 * @property string|null $metrics_frame
 * @property string|null $device
 * @property string|null $firmware
 * @property string|null $fingerprint
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class Measurement extends Model
{
    use BelongsToUser, HasUuids;

    public const array METRICS = ['bmi', 'fat_percent', 'muscle_percent', 'water_percent', 'visceral_or_bone', 'basal_kcal'];

    protected $table = 'health.measurements';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'measured_at' => 'immutable_datetime',
            'weight_kg' => 'decimal:2',
            'bmi' => 'decimal:1',
            'fat_percent' => 'decimal:1',
            'muscle_percent' => 'decimal:1',
            'water_percent' => 'decimal:1',
            'visceral_or_bone' => 'integer',
            'basal_kcal' => 'integer',
            'impedances' => 'array',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    public function weight(): float
    {
        return (float) $this->weight_kg;
    }

    public function hasMetrics(): bool
    {
        return $this->fat_percent !== null;
    }
}
