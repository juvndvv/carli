<?php

namespace App\Modules\Tasks\Http\Controllers;

use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Services\TaskListService;
use App\Modules\Tasks\Http\Requests\ReorderTaskListsRequest;
use App\Modules\Tasks\Http\Requests\StoreTaskListRequest;
use App\Modules\Tasks\Http\Resources\TaskListResource;
use App\Modules\Tasks\Models\TaskList;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class TaskListController extends TasksController
{
    public function __construct(private readonly TaskListService $lists) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $this->user($request);
        $this->lists->defaultFor($user);

        return TaskListResource::collection(
            TaskList::query()->ownedBy($user)
                ->when(! $request->boolean('archived'), fn (Builder $query) => $query->whereNull('archived_at'))
                ->withCount(['tasks as open_tasks_count' => fn (Builder $query) => $query->where('status', TaskStatus::Open->value)])
                ->orderByDesc('is_default')
                ->orderBy('sort_order')
                ->orderBy('name')
                ->get()
        );
    }

    public function store(StoreTaskListRequest $request): JsonResponse
    {
        /** @var array{name: string, color?: string|null, icon?: string|null} $data */
        $data = $request->safe()->except('archived');

        return (new TaskListResource($this->lists->create($request->tasksUser(), $data)))->response()->setStatusCode(201);
    }

    public function show(TaskList $list): TaskListResource
    {
        $this->authorizeOwner('view', $list);

        return new TaskListResource($list->loadCount(['tasks as open_tasks_count' => fn (Builder $query) => $query->where('status', TaskStatus::Open->value)]));
    }

    public function update(StoreTaskListRequest $request, TaskList $list): TaskListResource
    {
        $this->authorizeOwner('update', $list);

        /** @var array{name?: string, color?: string|null, icon?: string|null, archived?: bool} $data */
        $data = $request->validated();

        return new TaskListResource($this->lists->update($list, $data));
    }

    public function reorder(ReorderTaskListsRequest $request): Response
    {
        /** @var list<string> $ids */
        $ids = $request->validated('ids');
        $this->lists->reorder($request->tasksUser(), $ids);

        return response()->noContent();
    }

    public function destroy(TaskList $list): Response
    {
        $this->authorizeOwner('delete', $list);
        $this->lists->delete($list);

        return response()->noContent();
    }
}
