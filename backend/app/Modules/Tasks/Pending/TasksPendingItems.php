<?php

namespace App\Modules\Tasks\Pending;

use App\Core\Pending\DailyDigestContributor;
use App\Core\Pending\PendingItem;
use App\Core\Pending\PendingItemsProvider;
use App\Core\Pending\PendingPage;
use App\Models\User;
use App\Modules\Tasks\Domain\Services\OccurrenceGenerator;
use App\Modules\Tasks\Domain\Services\TaskAgenda;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use Carbon\CarbonImmutable;

final readonly class TasksPendingItems implements DailyDigestContributor, PendingItemsProvider
{
    public const string MODULE = 'tasks';

    public const string OVERDUE = 'overdue_task';

    public const string DUE_TODAY = 'task_due_today';

    public const string ROUTE = '/tareas/hoy';

    private const int PAGE_SIZE = 50;

    public function __construct(
        private TaskAgenda $agenda,
        private OccurrenceGenerator $generator,
    ) {}

    public function moduleId(): string
    {
        return self::MODULE;
    }

    public function counts(User $user): array
    {
        return [self::OVERDUE => $this->overdueCount($user)];
    }

    public function digestCounts(User $user): array
    {
        return [self::DUE_TODAY => $this->agenda->dueOn($user, TaskCalendar::today())->count()];
    }

    public function items(User $user, ?string $type, ?string $cursor): PendingPage
    {
        if ($type !== null && $type !== self::OVERDUE) {
            return PendingPage::empty();
        }

        $today = TaskCalendar::today();
        $offset = max(0, (int) ($cursor ?? 0));
        $rows = $this->agenda->overdue($user, $today)->offset($offset)->limit(self::PAGE_SIZE + 1)->get();
        $page = $rows->take(self::PAGE_SIZE);

        return new PendingPage(
            array_values($page->map(fn (Task $task) => $this->present($task, $today))->all()),
            $rows->count() > self::PAGE_SIZE ? (string) ($offset + self::PAGE_SIZE) : null,
        );
    }

    public function describe(string $type, int $count): string
    {
        return match ($type) {
            self::OVERDUE => $count === 1 ? '1 tarea vencida' : "{$count} tareas vencidas",
            self::DUE_TODAY => $count === 1 ? '1 tarea de hoy por hacer' : "{$count} tareas de hoy por hacer",
            default => $count === 1 ? '1 tarea' : "{$count} tareas",
        };
    }

    private function overdueCount(User $user): int
    {
        $today = TaskCalendar::today();
        $this->generator->catchUp($user, $today);

        return $this->agenda->overdue($user, $today)->count();
    }

    private function present(Task $task, CarbonImmutable $today): PendingItem
    {
        $due = $task->due_date ?? $today;
        $days = (int) $due->diffInDays($today);

        return new PendingItem(
            module: self::MODULE,
            type: self::OVERDUE,
            id: $task->id,
            title: $task->title,
            date: $due->toDateString(),
            route: self::ROUTE,
            subtitle: $task->list->name.' · '.($days === 1 ? 'Vencida ayer' : "Vencida hace {$days} días"),
            meta: [
                'task_id' => $task->id,
                'list_id' => $task->list_id,
                'template_id' => $task->template_id,
                'due_time' => TaskCalendar::time($task->due_time),
                'important' => $task->important,
            ],
        );
    }
}
