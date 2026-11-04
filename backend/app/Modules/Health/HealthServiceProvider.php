<?php

namespace App\Modules\Health;

use App\Core\Calendar\CalendarRegistry;
use App\Modules\Habits\Policies\OwnedByUserPolicy;
use App\Modules\Health\Calendar\HealthCalendarItems;
use App\Modules\Health\Console\SyncWhoopCommand;
use App\Modules\Health\Console\WeighRemindersCommand;
use App\Modules\Health\Domain\BodyService;
use App\Modules\Health\Domain\HealthSettings;
use App\Modules\Health\Domain\MeasurementService;
use App\Modules\Health\Domain\WhoopConnectionService;
use App\Modules\Health\Domain\WhoopDays;
use App\Modules\Health\Domain\WhoopSync;
use App\Modules\Health\Http\Controllers\WhoopCallbackController;
use App\Modules\Health\Http\Controllers\WhoopWebhookController;
use App\Modules\Health\Models\BodyMeasurement;
use App\Modules\Health\Models\BodySite;
use App\Modules\Health\Models\Measurement;
use App\Modules\Health\Whoop\WhoopClient;
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
        $this->app->singleton(WhoopClient::class);
        $this->app->scoped(WhoopSync::class);
        $this->app->scoped(WhoopConnectionService::class);
        $this->app->scoped(WhoopDays::class);
    }

    public function boot(): void
    {
        $this->loadMigrationsFrom(__DIR__.'/database/migrations');

        Route::prefix('api/v1/health')
            ->middleware(['api', 'auth:sanctum', 'module:health'])
            ->group(__DIR__.'/routes/api.php');

        // WHOOP's browser redirect and its webhooks carry no carli session.
        Route::prefix('api/v1/health/whoop')->middleware(['api'])->name('health.whoop.')->group(function (): void {
            Route::get('callback', WhoopCallbackController::class)->middleware('throttle:30,1')->name('callback');
            Route::post('webhook', WhoopWebhookController::class)->middleware('throttle:120,1')->name('webhook');
        });

        Gate::policy(Measurement::class, OwnedByUserPolicy::class);
        Gate::policy(BodySite::class, OwnedByUserPolicy::class);
        Gate::policy(BodyMeasurement::class, OwnedByUserPolicy::class);

        if ($this->app->runningInConsole()) {
            $this->commands([WeighRemindersCommand::class, SyncWhoopCommand::class]);
        }

        $this->callAfterResolving(Schedule::class, function (Schedule $schedule): void {
            $schedule->command('health:weigh-reminders')->everyMinute()->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
            $schedule->command('health:whoop-sync')->hourly()->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
        });
    }
}
