<?php

namespace App\Modules\Tasks\Models;

use App\Modules\Tasks\Domain\Enums\SkipReason;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string $list_id
 * @property string|null $template_id
 * @property CarbonImmutable|null $occurrence_date
 * @property string $title
 * @property string|null $notes
 * @property CarbonImmutable|null $due_date
 * @property string|null $due_time
 * @property TaskStatus $status
 * @property SkipReason|null $skip_reason
 * @property CarbonImmutable|null $completed_at
 * @property CarbonImmutable|null $skipped_at
 * @property bool $important
 * @property int $sort
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read TaskList $list
 * @property-read TaskTemplate|null $template
 * @property-read Collection<int, TaskSubtask> $subtasks
 */
class Task extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'tasks.tasks';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'status' => 'open',
        'important' => false,
        'sort' => 0,
    ];

    protected function casts(): array
    {
        return [
            'status' => TaskStatus::class,
            'skip_reason' => SkipReason::class,
            'important' => 'boolean',
            'sort' => 'integer',
            'occurrence_date' => 'immutable_date',
            'due_date' => 'immutable_date',
            'completed_at' => 'immutable_datetime',
            'skipped_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<TaskList, $this>
     */
    public function list(): BelongsTo
    {
        return $this->belongsTo(TaskList::class, 'list_id')->withoutGlobalScopes();
    }

    /**
     * @return BelongsTo<TaskTemplate, $this>
     */
    public function template(): BelongsTo
    {
        return $this->belongsTo(TaskTemplate::class, 'template_id')->withoutGlobalScopes();
    }

    /**
     * @return HasMany<TaskSubtask, $this>
     */
    public function subtasks(): HasMany
    {
        return $this->hasMany(TaskSubtask::class, 'task_id')->orderBy('sort')->orderBy('created_at');
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeOpen(Builder $query): void
    {
        $query->where($query->qualifyColumn('status'), TaskStatus::Open->value);
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeAgendaOrder(Builder $query): void
    {
        $query->orderByDesc('important')
            ->orderByRaw('due_time ASC NULLS LAST')
            ->orderBy('sort')
            ->orderBy('created_at')
            ->orderBy('id');
    }

    public function isOpen(): bool
    {
        return $this->status === TaskStatus::Open;
    }
}
