<?php

namespace App\Modules\Tasks\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $task_id
 * @property string $title
 * @property CarbonImmutable|null $done_at
 * @property int $sort
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Task $task
 */
class TaskSubtask extends Model
{
    use HasUuids;

    protected $table = 'tasks.task_subtasks';

    protected $guarded = ['id', 'task_id'];

    protected $attributes = [
        'sort' => 0,
    ];

    protected function casts(): array
    {
        return [
            'sort' => 'integer',
            'done_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Task, $this>
     */
    public function task(): BelongsTo
    {
        return $this->belongsTo(Task::class)->withoutGlobalScopes();
    }
}
