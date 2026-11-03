<?php

namespace App\Modules\Health\Models;

use App\Modules\Habits\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A place on the body measured with a tape (cintura, brazo izquierdo…).
 *
 * @property string $id
 * @property string $user_id
 * @property string $name
 * @property string $zone
 * @property string|null $side
 * @property int $position
 * @property CarbonImmutable|null $archived_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class BodySite extends Model
{
    use BelongsToUser, HasUuids;

    /** Zones the body viewer knows how to place, top to bottom. */
    public const array ZONES = ['neck', 'shoulders', 'chest', 'arm', 'forearm', 'wrist', 'waist', 'abdomen', 'hips', 'thigh', 'calf', 'ankle'];

    /** Zones that come in pairs and take a side. */
    public const array PAIRED = ['arm', 'forearm', 'wrist', 'thigh', 'calf', 'ankle'];

    /** The sites a new user starts with. */
    public const array DEFAULTS = [
        ['Cuello', 'neck', null],
        ['Pecho', 'chest', null],
        ['Brazo izquierdo', 'arm', 'left'],
        ['Brazo derecho', 'arm', 'right'],
        ['Cintura', 'waist', null],
        ['Abdomen', 'abdomen', null],
        ['Cadera', 'hips', null],
        ['Muslo izquierdo', 'thigh', 'left'],
        ['Muslo derecho', 'thigh', 'right'],
        ['Gemelo izquierdo', 'calf', 'left'],
        ['Gemelo derecho', 'calf', 'right'],
    ];

    protected $table = 'health.body_sites';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'position' => 'integer',
            'archived_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return HasMany<BodyMeasurement, $this>
     */
    public function measurements(): HasMany
    {
        return $this->hasMany(BodyMeasurement::class, 'site_id');
    }
}
