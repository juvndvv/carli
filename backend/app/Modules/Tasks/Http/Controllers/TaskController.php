<?php

namespace App\Modules\Tasks\Http\Controllers;

use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Services\TaskService;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Http\Requests\PostponeTaskRequest;
use App\Modules\Tasks\Http\Requests\StoreTaskRequest;
use App\Modules\Tasks\Http\Requests\TaskIndexRequest;
use App\Modules\Tasks\Http\Resources\TaskResource;
use App\Modules\Tasks\Models\Task;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class TaskController extends TasksController
{
    private const int PAGE_SIZE = 100;

    public function __construct(private readonly TaskService $tasks) {}

    public function index(TaskIndexRequest $request): AnonymousResourceCollection
    {
        $status = (string) $request->validated('status', 'open');
        $term = trim((string) $request->validated('q', ''));
        $from = $request->validated('from');
        $to = $request->validated('to');

        $query = Task::query()->ownedBy($request->tasksUser())
            ->with(['list', 'subtasks', 'template'])
            ->when($request->validated('list_id'), fn (Builder $query, mixed $list) => $query->where('list_id', $list))
            ->when($status !== 'all', fn (Builder $query) => $query->where('status', $status === 'done' ? TaskStatus::Done->value : TaskStatus::Open->value))
            ->when($term !== '', fn (Builder $query) => $query->where('title', 'ILIKE', '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term).'%'))
            ->when(is_string($from), fn (Builder $query) => $query->where('completed_at', '>=', TaskCalendar::date((string) $from)))
            ->when(is_string($to), fn (Builder $query) => $query->where('completed_at', '<', TaskCalendar::date((string) $to)->addDay()));

        if ($status === 'done') {
            $query->orderByDesc('completed_at')->orderByDesc('id');
        } else {
            $query->orderByRaw('due_date ASC NULLS LAST')->agendaOrder();
        }

        return TaskResource::collection($query->paginate(self::PAGE_SIZE));
    }

    public function store(StoreTaskRequest $request): JsonResponse
    {
        /** @var array{title: string, notes?: string|null, list_id?: string|null, due_date?: string|null, due_time?: string|null, important?: bool, subtasks?: list<string>} $data */
        $data = $request->validated();

        return (new TaskResource($this->tasks->create($request->tasksUser(), $data)))->response()->setStatusCode(201);
    }

    public function show(Task $task): TaskResource
    {
        $this->authorizeOwner('view', $task);

        return new TaskResource($task);
    }

    public function update(StoreTaskRequest $request, Task $task): TaskResource
    {
        $this->authorizeOwner('update', $task);

        return new TaskResource($this->tasks->update($task, $request->validated()));
    }

    public function complete(Task $task): TaskResource
    {
        $this->authorizeOwner('update', $task);

        return new TaskResource($this->tasks->complete($task));
    }

    public function reopen(Task $task): TaskResource
    {
        $this->authorizeOwner('update', $task);

        return new TaskResource($this->tasks->reopen($task));
    }

    public function skip(Task $task): TaskResource
    {
        $this->authorizeOwner('update', $task);

        return new TaskResource($this->tasks->skip($task));
    }

    public function postpone(PostponeTaskRequest $request, Task $task): TaskResource
    {
        $this->authorizeOwner('update', $task);

        return new TaskResource($this->tasks->postpone($task, TaskCalendar::date((string) $request->validated('date'))));
    }

    public function destroy(Task $task): Response
    {
        $this->authorizeOwner('delete', $task);
        $this->tasks->delete($task);

        return response()->noContent();
    }
}
