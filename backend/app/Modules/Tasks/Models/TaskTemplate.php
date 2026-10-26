<?php

namespace App\Modules\Tasks\Models;

use App\Core\Recurrence\RecurrenceRule;
use App\Modules\Tasks\Domain\Enums\TemplatePolicy;
use App\Modules\Tasks\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string $list_id
 * @property string $title
 * @property string|null $notes
 * @property list<string> $subtasks
 * @property string|null $rrule
 * @property CarbonImmutable $dtstart
 * @property CarbonImmutable|null $until
 * @property int|null $count
 * @property int|null $after_done_interval_days
 * @property TemplatePolicy $policy
 * @property int $lead_days
 * @property string|null $due_time
 * @property bool $important
 * @property CarbonImmutable|null $generated_through
 * @property CarbonImmutable|null $next_due_date
 * @property CarbonImmutable|null $paused_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read TaskList $list
 */
class TaskTemplate extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'tasks.task_templates';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'subtasks' => '[]',
        'policy' => 'replace',
        'lead_days' => 0,
        'important' => false,
    ];

    protected function casts(): array
    {
        return [
            'subtasks' => 'array',
            'policy' => TemplatePolicy::class,
            'count' => 'integer',
            'after_done_interval_days' => 'integer',
            'lead_days' => 'integer',
            'important' => 'boolean',
            'dtstart' => 'immutable_date',
            'until' => 'immutable_date',
            'generated_through' => 'immutable_date',
            'next_due_date' => 'immutable_date',
            'paused_at' => 'immutable_datetime',
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
     * @return HasMany<Task, $this>
     */
    public function tasks(): HasMany
    {
        return $this->hasMany(Task::class, 'template_id')->withoutGlobalScopes();
    }

    /**
     * @return HasMany<TaskTemplateException, $this>
     */
    public function exceptions(): HasMany
    {
        return $this->hasMany(TaskTemplateException::class, 'template_id');
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeActive(Builder $query): void
    {
        $query->whereNull('paused_at');
    }

    public function isAfterDone(): bool
    {
        return $this->after_done_interval_days !== null;
    }

    public function isPaused(): bool
    {
        return $this->paused_at !== null;
    }

    public function recurrence(): ?RecurrenceRule
    {
        return $this->rrule === null ? null : RecurrenceRule::parse($this->rrule, $this->dtstart, $this->until, $this->count);
    }
}
