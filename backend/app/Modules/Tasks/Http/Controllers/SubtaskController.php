<?php

namespace App\Modules\Tasks\Http\Controllers;

use App\Modules\Tasks\Domain\Services\TaskService;
use App\Modules\Tasks\Http\Requests\StoreSubtaskRequest;
use App\Modules\Tasks\Http\Resources\SubtaskResource;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskSubtask;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;

final class SubtaskController extends TasksController
{
    public function __construct(private readonly TaskService $tasks) {}

    public function store(StoreSubtaskRequest $request, Task $task): JsonResponse
    {
        $this->authorizeOwner('update', $task);

        return (new SubtaskResource($this->tasks->addSubtask($task, (string) $request->validated('title'))))->response()->setStatusCode(201);
    }

    public function update(StoreSubtaskRequest $request, Task $task, TaskSubtask $subtask): SubtaskResource
    {
        $this->authorizeSubtask($task, $subtask);

        /** @var array{title?: string, done?: bool, sort?: int} $data */
        $data = $request->validated();

        return new SubtaskResource($this->tasks->updateSubtask($subtask, $data));
    }

    public function destroy(Task $task, TaskSubtask $subtask): Response
    {
        $this->authorizeSubtask($task, $subtask);
        $subtask->delete();

        return response()->noContent();
    }

    private function authorizeSubtask(Task $task, TaskSubtask $subtask): void
    {
        $this->authorizeOwner('update', $task);
        abort_unless($subtask->task_id === $task->id, 404);
    }
}
