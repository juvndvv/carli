<?php

namespace App\Modules\Tasks\Calendar;

use App\Core\Calendar\CalendarItem;
use App\Core\Calendar\CalendarItemsProvider;
use App\Models\User;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Services\OccurrenceGenerator;
use App\Modules\Tasks\Domain\Services\TasksSettings;
use App\Modules\Tasks\Domain\Services\TemplateService;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;
use Carbon\CarbonImmutable;

/**
 * Tasks on their due day (open and done) plus the template occurrences not generated yet,
 * which the app shows dimmed under the "templates" source.
 */
final readonly class TasksCalendarItems implements CalendarItemsProvider
{
    public const string SOURCE = 'tasks';

    public const string TEMPLATES = 'templates';

    public function __construct(
        private OccurrenceGenerator $generator,
        private TemplateService $templates,
    ) {}

    public function moduleId(): string
    {
        return TasksSettings::MODULE;
    }

    public function items(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $today = TaskCalendar::today();
        $this->generator->catchUp($user, $today);

        $tasks = Task::query()->ownedBy($user)
            ->whereIn('status', [TaskStatus::Open->value, TaskStatus::Done->value])
            ->whereDate('due_date', '>=', $from->toDateString())
            ->whereDate('due_date', '<=', $to->toDateString())
            ->with('list')
            ->get();

        $items = [];

        foreach ($tasks as $task) {
            if ($task->due_date === null) {
                continue;
            }

            $items[] = new CalendarItem(
                source: self::SOURCE,
                id: $task->id,
                title: $task->title,
                date: TaskCalendar::date($task->due_date),
                time: TaskCalendar::time($task->due_time),
                done: $task->status === TaskStatus::Done,
                subtitle: $task->list->is_default ? null : $task->list->name,
                url: '/tareas/tarea/'.$task->id,
                meta: [
                    'task_id' => $task->id,
                    'important' => $task->important,
                    'overdue' => $task->status === TaskStatus::Open && $task->due_date->lt($today),
                ],
            );
        }

        if ($to->lt($today)) {
            return $items;
        }

        $start = $from->max($today);
        $days = (int) $start->diffInDays($to) + 1;
        $templates = TaskTemplate::query()->ownedBy($user)->active()->with('list')->get();

        foreach ($templates as $template) {
            foreach ($this->templates->upcomingDates($template, $start, $days) as $date) {
                if ($date->gt($to)) {
                    break;
                }

                $items[] = new CalendarItem(
                    source: self::TEMPLATES,
                    id: $template->id.':'.$date->toDateString(),
                    title: $template->title,
                    date: TaskCalendar::date($date),
                    time: TaskCalendar::time($template->due_time),
                    subtitle: TemplateService::describe($template),
                    url: '/tareas/plantillas/'.$template->id,
                    meta: ['template_id' => $template->id, 'important' => $template->important],
                );
            }
        }

        return $items;
    }
}
