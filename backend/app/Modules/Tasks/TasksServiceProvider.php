<?php

namespace App\Modules\Tasks;

use App\Core\Pending\PendingRegistry;
use App\Core\Search\ModuleSearcher;
use App\Modules\Tasks\Console\GenerateTasksCommand;
use App\Modules\Tasks\Domain\Services\OccurrenceGenerator;
use App\Modules\Tasks\Domain\Services\TaskAgenda;
use App\Modules\Tasks\Domain\Services\TaskListService;
use App\Modules\Tasks\Domain\Services\TaskService;
use App\Modules\Tasks\Domain\Services\TasksSettings;
use App\Modules\Tasks\Domain\Services\TemplateService;
use App\Modules\Tasks\Http\Middleware\EnsureTasksInitialized;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskList;
use App\Modules\Tasks\Models\TaskTemplate;
use App\Modules\Tasks\Pending\TasksPendingItems;
use App\Modules\Tasks\Policies\OwnedByUserPolicy;
use App\Modules\Tasks\Search\TasksSearcher;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class TasksServiceProvider extends ServiceProvider
{
    public const string TIMEZONE = 'Europe/Madrid';

    private const array SCOPED_SERVICES = [
        TaskListService::class,
        TasksSettings::class,
        OccurrenceGenerator::class,
        TaskService::class,
        TemplateService::class,
        TaskAgenda::class,
    ];

    private const array OWNED_MODELS = [TaskList::class, Task::class, TaskTemplate::class];

    public static function manifestPath(): string
    {
        return __DIR__.'/module.php';
    }

    public function register(): void
    {
        foreach (self::SCOPED_SERVICES as $service) {
            $this->app->scoped($service);
        }

        $this->app->tag([TasksSearcher::class], ModuleSearcher::TAG);

        $this->callAfterResolving(PendingRegistry::class, fn (PendingRegistry $pending) => $pending->register(TasksPendingItems::class));
    }

    public function boot(): void
    {
        $this->loadMigrationsFrom(__DIR__.'/database/migrations');

        Route::prefix('api/v1/tasks')
            ->middleware(['api', 'auth:sanctum', 'module:tasks', EnsureTasksInitialized::class])
            ->group(__DIR__.'/routes/api.php');

        foreach (self::OWNED_MODELS as $model) {
            Gate::policy($model, OwnedByUserPolicy::class);
        }

        if ($this->app->runningInConsole()) {
            $this->commands([GenerateTasksCommand::class]);
        }

        $this->callAfterResolving(Schedule::class, function (Schedule $schedule): void {
            $schedule->command('tasks:generate')->dailyAt('00:05')->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
        });
    }
}
