<?php

namespace App\Modules\Tasks\Search;

use App\Core\Recurrence\RecurrenceDescriber;
use App\Core\Search\ModuleSearcher;
use App\Core\Search\SearchResult;
use App\Models\User;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Services\TemplateService;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;

final class TasksSearcher implements ModuleSearcher
{
    public function moduleId(): string
    {
        return 'tasks';
    }

    public function search(User $user, string $query, int $limit): array
    {
        $term = trim($query);
        if ($term === '') {
            return [];
        }

        $like = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term).'%';
        $results = [];

        foreach (TaskTemplate::query()->ownedBy($user)->where('title', 'ILIKE', $like)->orderBy('title')->limit($limit)->get() as $template) {
            $results[] = new SearchResult(
                type: 'task_template',
                id: $template->id,
                title: $template->title,
                url: '/tareas/plantillas/'.$template->id,
                subtitle: TemplateService::describe($template),
                icon: 'repeat',
            );
        }

        $tasks = Task::query()->ownedBy($user)->with('list')
            ->where('title', 'ILIKE', $like)
            ->where('status', '!=', TaskStatus::Skipped->value)
            ->orderByRaw("status = 'done'")
            ->orderByRaw('due_date ASC NULLS LAST')
            ->limit($limit)
            ->get();

        foreach ($tasks as $task) {
            $results[] = new SearchResult(
                type: 'task',
                id: $task->id,
                title: $task->title,
                url: '/tareas/tarea/'.$task->id,
                subtitle: $task->list->name
                    .($task->due_date !== null ? ' · '.RecurrenceDescriber::shortDate($task->due_date) : '')
                    .($task->status === TaskStatus::Done ? ' · Hecha' : ''),
                icon: $task->status === TaskStatus::Done ? 'circle-check' : 'circle',
            );
        }

        return array_slice($results, 0, $limit);
    }
}
