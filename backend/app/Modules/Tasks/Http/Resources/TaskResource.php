<?php

namespace App\Modules\Tasks\Http\Resources;

use App\Modules\Tasks\Domain\Services\TemplateService;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskSubtask;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Task
 */
final class TaskResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Task $task */
        $task = $this->resource;
        $task->loadMissing(['list', 'subtasks', 'template']);
        $today = TaskCalendar::today();

        return [
            'id' => $task->id,
            'title' => $task->title,
            'notes' => $task->notes,
            'list_id' => $task->list_id,
            'list' => ['id' => $task->list->id, 'name' => $task->list->name, 'color' => $task->list->color, 'is_default' => $task->list->is_default],
            'due_date' => $task->due_date?->toDateString(),
            'due_time' => TaskCalendar::time($task->due_time),
            'status' => $task->status->value,
            'skip_reason' => $task->skip_reason?->value,
            'overdue' => $task->isOpen() && $task->due_date !== null && $task->due_date->lt($today),
            'important' => $task->important,
            'sort' => $task->sort,
            'completed_at' => $task->completed_at?->toIso8601String(),
            'skipped_at' => $task->skipped_at?->toIso8601String(),
            'template_id' => $task->template_id,
            'occurrence_date' => $task->occurrence_date?->toDateString(),
            'template' => $task->template === null ? null : [
                'id' => $task->template->id,
                'title' => $task->template->title,
                'frequency_text' => TemplateService::describe($task->template),
                'paused' => $task->template->isPaused(),
            ],
            'subtasks' => array_values($task->subtasks->map(fn (TaskSubtask $subtask) => SubtaskResource::present($subtask))->all()),
            'subtasks_done' => $task->subtasks->whereNotNull('done_at')->count(),
            'created_at' => $task->created_at?->toIso8601String(),
            'updated_at' => $task->updated_at?->toIso8601String(),
        ];
    }
}
