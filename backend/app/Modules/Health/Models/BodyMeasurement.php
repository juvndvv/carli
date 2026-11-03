<?php

namespace App\Modules\Health\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One tape measurement of a body site.
 *
 * @property string $id
 * @property string $user_id
 * @property string $site_id
 * @property CarbonImmutable $measured_at
 * @property string $value_cm
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class BodyMeasurement extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'health.body_measurements';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'measured_at' => 'immutable_datetime',
            'value_cm' => 'decimal:1',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<BodySite, $this>
     */
    public function site(): BelongsTo
    {
        return $this->belongsTo(BodySite::class, 'site_id');
    }

    public function value(): float
    {
        return (float) $this->value_cm;
    }
}
