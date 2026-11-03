<?php

namespace App\Modules\Tasks\Console;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Services\TasksSettings;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Notifications\TaskDue;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

final class TaskDueRemindersCommand extends Command
{
    /** A task whose time passed less than this ago still gets its push (a missed scheduler minute). */
    public const int GRACE_MINUTES = 10;

    protected $signature = 'tasks:due-reminders';

    protected $description = 'Avisa de las tareas pendientes de hoy cuando llega su hora';

    public function handle(ModuleRegistry $modules): int
    {
        $now = CarbonImmutable::now(TaskCalendar::TIMEZONE);
        $sent = 0;

        $tasks = Task::query()->withoutGlobalScopes()
            ->where('status', TaskStatus::Open->value)
            ->whereDate('due_date', $now->toDateString())
            ->whereNotNull('due_time')
            ->where('due_time', '<=', $now->format('H:i:59'))
            ->where('due_time', '>=', $now->subMinutes(self::GRACE_MINUTES)->format('H:i:00'))
            ->whereNull('reminded_at')
            ->with(['list', 'user'])
            ->get();

        foreach ($tasks as $task) {
            $user = $task->user;

            if (! $user instanceof User || ! $modules->isEnabledFor($user, TasksSettings::MODULE)) {
                continue;
            }

            // Marked first, so a slow push never repeats on the next run.
            $task->forceFill(['reminded_at' => $now])->saveQuietly();
            $user->notify(new TaskDue($task->id, $task->title, (string) TaskCalendar::time($task->due_time), $task->list->is_default ? null : $task->list->name));
            $sent++;
        }

        $this->info("Avisos enviados: {$sent}");

        return self::SUCCESS;
    }
}
