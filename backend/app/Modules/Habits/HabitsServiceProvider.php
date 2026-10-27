<?php

namespace App\Modules\Habits;

use App\Core\Pending\PendingRegistry;
use App\Core\Search\ModuleSearcher;
use App\Modules\Habits\Digest\HabitsDigestProvider;
use App\Modules\Habits\Domain\Evaluation\HabitEvaluator;
use App\Modules\Habits\Domain\Services\BreakService;
use App\Modules\Habits\Domain\Services\EntryService;
use App\Modules\Habits\Domain\Services\HabitReport;
use App\Modules\Habits\Domain\Services\HabitService;
use App\Modules\Habits\Domain\Services\HabitsSettings;
use App\Modules\Habits\Domain\Services\TemplateConversion;
use App\Modules\Habits\Models\Habit;
use App\Modules\Habits\Models\HabitBreak;
use App\Modules\Habits\Policies\OwnedByUserPolicy;
use App\Modules\Habits\Search\HabitsSearcher;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class HabitsServiceProvider extends ServiceProvider
{
    public const string TIMEZONE = 'Europe/Madrid';

    private const array SCOPED_SERVICES = [
        HabitsSettings::class,
        HabitEvaluator::class,
        HabitService::class,
        EntryService::class,
        BreakService::class,
        HabitReport::class,
        TemplateConversion::class,
    ];

    private const array OWNED_MODELS = [Habit::class, HabitBreak::class];

    public static function manifestPath(): string
    {
        return __DIR__.'/module.php';
    }

    public function register(): void
    {
        foreach (self::SCOPED_SERVICES as $service) {
            $this->app->scoped($service);
        }

        $this->app->tag([HabitsSearcher::class], ModuleSearcher::TAG);

        $this->callAfterResolving(PendingRegistry::class, fn (PendingRegistry $pending) => $pending->registerDigestLines(HabitsDigestProvider::class));
    }

    public function boot(): void
    {
        $this->loadMigrationsFrom(__DIR__.'/database/migrations');

        Route::prefix('api/v1/habits')
            ->middleware(['api', 'auth:sanctum', 'module:habits'])
            ->group(__DIR__.'/routes/api.php');

        foreach (self::OWNED_MODELS as $model) {
            Gate::policy($model, OwnedByUserPolicy::class);
        }
    }
}
