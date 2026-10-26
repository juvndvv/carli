<?php

namespace App\Modules\Tasks\Domain\Services;

use App\Models\User;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;

final readonly class TaskAgenda
{
    public const int UPCOMING_DAYS = 14;

    public function __construct(
        private OccurrenceGenerator $generator,
        private TemplateService $templates,
    ) {}

    /**
     * @return array{date: string, overdue: Collection<int, Task>, today: Collection<int, Task>, done: Collection<int, Task>}
     */
    public function today(User $user, ?CarbonImmutable $today = null): array
    {
        $today ??= TaskCalendar::today();
        $this->generator->catchUp($user, $today);

        return [
            'date' => $today->toDateString(),
            'overdue' => $this->overdue($user, $today)->get(),
            'today' => $this->dueOn($user, $today)->get(),
            'done' => $this->doneOn($user, $today)->get(),
        ];
    }

    /**
     * @return Builder<Task>
     */
    public function overdue(User $user, CarbonImmutable $today): Builder
    {
        return $this->tasks($user)->open()
            ->whereDate('due_date', '<', $today->toDateString())
            ->orderBy('due_date')
            ->agendaOrder();
    }

    /**
     * @return Builder<Task>
     */
    public function dueOn(User $user, CarbonImmutable $date): Builder
    {
        return $this->tasks($user)->open()->whereDate('due_date', $date->toDateString())->agendaOrder();
    }

    /**
     * @return Builder<Task>
     */
    public function doneOn(User $user, CarbonImmutable $date): Builder
    {
        return $this->tasks($user)
            ->where('status', TaskStatus::Done->value)
            ->where('completed_at', '>=', $date->startOfDay())
            ->where('completed_at', '<', $date->addDay()->startOfDay())
            ->orderByDesc('completed_at');
    }

    /**
     * @return list<array{date: string, tasks: list<Task>, occurrences: list<array{template: TaskTemplate, date: string}>}>
     */
    public function upcoming(User $user, int $days = self::UPCOMING_DAYS, ?CarbonImmutable $today = null): array
    {
        $today ??= TaskCalendar::today();
        $this->generator->catchUp($user, $today);
        $end = $today->addDays($days - 1);

        $agenda = [];
        for ($date = $today; $date->lte($end); $date = $date->addDay()) {
            $agenda[$date->toDateString()] = ['date' => $date->toDateString(), 'tasks' => [], 'occurrences' => []];
        }

        $tasks = $this->tasks($user)->open()
            ->whereDate('due_date', '>=', $today->toDateString())
            ->whereDate('due_date', '<=', $end->toDateString())
            ->orderBy('due_date')
            ->agendaOrder()
            ->get();

        foreach ($tasks as $task) {
            $key = $task->due_date?->toDateString();
            if ($key !== null && isset($agenda[$key])) {
                $agenda[$key]['tasks'][] = $task;
            }
        }

        $templates = TaskTemplate::query()->ownedBy($user)->active()->with('list')->orderBy('title')->get();

        foreach ($templates as $template) {
            foreach ($this->templates->upcomingDates($template, $today, $days) as $date) {
                $key = $date->toDateString();
                if (! isset($agenda[$key])) {
                    break;
                }

                $agenda[$key]['occurrences'][] = ['template' => $template, 'date' => $key];
            }
        }

        return array_values($agenda);
    }

    /**
     * @return Builder<Task>
     */
    private function tasks(User $user): Builder
    {
        return Task::query()->ownedBy($user)->with(['list', 'subtasks', 'template']);
    }
}
