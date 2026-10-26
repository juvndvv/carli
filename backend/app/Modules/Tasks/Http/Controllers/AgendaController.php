<?php

namespace App\Modules\Tasks\Http\Controllers;

use App\Modules\Tasks\Domain\Services\TaskAgenda;
use App\Modules\Tasks\Domain\Services\TemplateService;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Http\Requests\UpcomingRequest;
use App\Modules\Tasks\Http\Resources\TaskResource;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class AgendaController extends TasksController
{
    public function __construct(private readonly TaskAgenda $agenda) {}

    public function today(Request $request): JsonResponse
    {
        $today = $this->agenda->today($this->user($request));
        $done = $today['done']->count();

        return response()->json(['data' => [
            'date' => $today['date'],
            'overdue' => TaskResource::collection($today['overdue'])->resolve($request),
            'today' => TaskResource::collection($today['today'])->resolve($request),
            'done' => TaskResource::collection($today['done'])->resolve($request),
            'progress' => ['done' => $done, 'total' => $done + $today['today']->count()],
        ]]);
    }

    public function upcoming(UpcomingRequest $request): JsonResponse
    {
        $days = $this->agenda->upcoming($request->tasksUser(), (int) $request->validated('days', TaskAgenda::UPCOMING_DAYS));

        return response()->json(['data' => array_map(fn (array $day) => [
            'date' => $day['date'],
            'tasks' => array_map(fn (Task $task) => (new TaskResource($task))->resolve($request), $day['tasks']),
            'occurrences' => array_map(fn (array $occurrence) => $this->occurrence($occurrence['template'], $occurrence['date']), $day['occurrences']),
        ], $days)]);
    }

    /**
     * @return array<string, mixed>
     */
    private function occurrence(TaskTemplate $template, string $date): array
    {
        return [
            'template_id' => $template->id,
            'date' => $date,
            'title' => $template->title,
            'list' => ['id' => $template->list->id, 'name' => $template->list->name, 'color' => $template->list->color, 'is_default' => $template->list->is_default],
            'due_time' => TaskCalendar::time($template->due_time),
            'important' => $template->important,
            'frequency_text' => TemplateService::describe($template),
        ];
    }
}
