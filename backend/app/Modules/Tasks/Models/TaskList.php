<?php

namespace App\Modules\Tasks\Models;

use App\Modules\Tasks\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string $name
 * @property string|null $color
 * @property string|null $icon
 * @property bool $is_default
 * @property int $sort_order
 * @property CarbonImmutable|null $archived_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property int|null $open_tasks_count
 */
class TaskList extends Model
{
    use BelongsToUser, HasUuids;

    public const string DEFAULT_NAME = 'Bandeja';

    protected $table = 'tasks.task_lists';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'is_default' => false,
        'sort_order' => 0,
    ];

    protected function casts(): array
    {
        return [
            'is_default' => 'boolean',
            'sort_order' => 'integer',
            'archived_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return HasMany<Task, $this>
     */
    public function tasks(): HasMany
    {
        return $this->hasMany(Task::class, 'list_id')->withoutGlobalScopes();
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeActive(Builder $query): void
    {
        $query->whereNull('archived_at');
    }
}
