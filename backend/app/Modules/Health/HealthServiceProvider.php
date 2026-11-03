<?php

namespace App\Modules\Health;

use App\Core\Calendar\CalendarRegistry;
use App\Modules\Habits\Policies\OwnedByUserPolicy;
use App\Modules\Health\Calendar\HealthCalendarItems;
use App\Modules\Health\Console\WeighRemindersCommand;
use App\Modules\Health\Domain\BodyService;
use App\Modules\Health\Domain\HealthSettings;
use App\Modules\Health\Domain\MeasurementService;
use App\Modules\Health\Models\BodyMeasurement;
use App\Modules\Health\Models\BodySite;
use App\Modules\Health\Models\Measurement;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class HealthServiceProvider extends ServiceProvider
{
    public const string TIMEZONE = 'Europe/Madrid';

    public static function manifestPath(): string
    {
        return __DIR__.'/module.php';
    }

    public function register(): void
    {
        $this->callAfterResolving(CalendarRegistry::class, fn (CalendarRegistry $calendar) => $calendar->register(HealthCalendarItems::class));
        $this->app->scoped(HealthSettings::class);
        $this->app->scoped(MeasurementService::class);
        $this->app->scoped(BodyService::class);
    }

    public function boot(): void
    {
        $this->loadMigrationsFrom(__DIR__.'/database/migrations');

        Route::prefix('api/v1/health')
            ->middleware(['api', 'auth:sanctum', 'module:health'])
            ->group(__DIR__.'/routes/api.php');

        Gate::policy(Measurement::class, OwnedByUserPolicy::class);
        Gate::policy(BodySite::class, OwnedByUserPolicy::class);
        Gate::policy(BodyMeasurement::class, OwnedByUserPolicy::class);

        if ($this->app->runningInConsole()) {
            $this->commands([WeighRemindersCommand::class]);
        }

        $this->callAfterResolving(Schedule::class, function (Schedule $schedule): void {
            $schedule->command('health:weigh-reminders')->everyMinute()->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
        });
    }
}
