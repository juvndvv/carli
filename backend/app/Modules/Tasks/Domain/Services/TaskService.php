<?php

namespace App\Modules\Tasks\Domain\Services;

use App\Models\User;
use App\Modules\Tasks\Domain\Enums\SkipReason;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskSubtask;
use App\Modules\Tasks\Models\TaskTemplate;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class TaskService
{
    public function __construct(
        private readonly TaskListService $lists,
        private readonly TasksSettings $settings,
        private readonly OccurrenceGenerator $generator,
    ) {}

    /**
     * @param  array{title: string, notes?: string|null, list_id?: string|null, due_date?: string|null, due_time?: string|null, important?: bool, subtasks?: list<string>}  $data
     */
    public function create(User $user, array $data): Task
    {
        return DB::transaction(function () use ($user, $data): Task {
            $task = new Task([
                'list_id' => $data['list_id'] ?? $this->settings->defaultListId($user) ?? $this->lists->defaultFor($user)->id,
                'title' => trim($data['title']),
                'notes' => $data['notes'] ?? null,
                'due_date' => $data['due_date'] ?? null,
                'due_time' => isset($data['due_date']) ? ($data['due_time'] ?? null) : null,
                'important' => (bool) ($data['important'] ?? false),
            ]);
            $task->user_id = $user->id;
            $task->save();

            foreach ($data['subtasks'] ?? [] as $position => $title) {
                $task->subtasks()->create(['title' => trim($title), 'sort' => $position]);
            }

            return $task;
        });
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Task $task, array $data): Task
    {
        if (isset($data['title']) && is_string($data['title'])) {
            $data['title'] = trim($data['title']);
        }

        $task->fill($data);

        if ($task->due_date === null) {
            $task->due_time = null;
        }

        $task->save();

        return $task;
    }

    public function complete(Task $task): Task
    {
        return DB::transaction(function () use ($task): Task {
            $task->status = TaskStatus::Done;
            $task->completed_at = now()->toImmutable();
            $task->skip_reason = null;
            $task->skipped_at = null;
            $task->save();

            $this->scheduleNextAfterDone($task, TaskCalendar::today());

            return $task;
        });
    }

    public function skip(Task $task): Task
    {
        return DB::transaction(function () use ($task): Task {
            $task->status = TaskStatus::Skipped;
            $task->skip_reason = SkipReason::Manual;
            $task->skipped_at = now()->toImmutable();
            $task->completed_at = null;
            $task->save();

            $this->scheduleNextAfterDone($task, TaskCalendar::today());

            return $task;
        });
    }

    public function reopen(Task $task): Task
    {
        return DB::transaction(function () use ($task): Task {
            $task->status = TaskStatus::Open;
            $task->completed_at = null;
            $task->skip_reason = null;
            $task->skipped_at = null;
            $task->save();

            $template = $task->template;
            if ($template !== null && $template->isAfterDone() && $template->next_due_date !== null) {
                $template->next_due_date = null;
                $template->save();
            }

            return $task;
        });
    }

    public function postpone(Task $task, CarbonImmutable $date): Task
    {
        $task->due_date = $date;
        $task->save();

        return $task;
    }

    public function delete(Task $task): void
    {
        DB::transaction(function () use ($task): void {
            if ($task->isOpen()) {
                $this->scheduleNextAfterDone($task, TaskCalendar::today());
            }

            $task->delete();
        });
    }

    public function addSubtask(Task $task, string $title): TaskSubtask
    {
        return $task->subtasks()->create([
            'title' => trim($title),
            'sort' => (int) $task->subtasks()->max('sort') + 1,
        ]);
    }

    /**
     * @param  array{title?: string, done?: bool, sort?: int}  $data
     */
    public function updateSubtask(TaskSubtask $subtask, array $data): TaskSubtask
    {
        if (array_key_exists('done', $data)) {
            $subtask->done_at = $data['done'] ? ($subtask->done_at ?? now()->toImmutable()) : null;
        }

        if (isset($data['title'])) {
            $subtask->title = trim($data['title']);
        }

        if (isset($data['sort'])) {
            $subtask->sort = $data['sort'];
        }

        $subtask->save();

        return $subtask;
    }

    private function scheduleNextAfterDone(Task $task, CarbonImmutable $today): void
    {
        $template = $task->template_id === null ? null : TaskTemplate::query()->withoutGlobalScopes()->find($task->template_id);

        if ($template === null || ! $template->isAfterDone()) {
            return;
        }

        $template->next_due_date = $today->addDays((int) $template->after_done_interval_days);
        $template->save();

        $this->generator->forget($template->user_id);
        $this->generator->generate($template, $today);
    }
}
