<?php

namespace App\Modules\Calendar;

use App\Core\Calendar\CalendarRegistry;
use App\Core\Pending\PendingRegistry;
use App\Modules\Calendar\Console\SyncGoogleCalendarsCommand;
use App\Modules\Calendar\Digest\CalendarDigestProvider;
use App\Modules\Calendar\Domain\GoogleConnectionService;
use App\Modules\Calendar\Domain\GoogleSync;
use App\Modules\Calendar\Google\GoogleClient;
use App\Modules\Calendar\Http\Controllers\GoogleCallbackController;
use App\Modules\Calendar\Items\GoogleEventItems;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class CalendarServiceProvider extends ServiceProvider
{
    public const string MODULE = 'calendar';

    public const string TIMEZONE = 'Europe/Madrid';

    public static function manifestPath(): string
    {
        return __DIR__.'/module.php';
    }

    public function register(): void
    {
        $this->app->singleton(GoogleClient::class);
        $this->app->scoped(GoogleSync::class);
        $this->app->scoped(GoogleConnectionService::class);

        $this->callAfterResolving(CalendarRegistry::class, fn (CalendarRegistry $calendar) => $calendar->register(GoogleEventItems::class));
        $this->callAfterResolving(PendingRegistry::class, fn (PendingRegistry $pending) => $pending->registerDigestLines(CalendarDigestProvider::class));
    }

    public function boot(): void
    {
        $this->loadMigrationsFrom(__DIR__.'/database/migrations');

        Route::prefix('api/v1/calendar')
            ->middleware(['api', 'auth:sanctum', 'module:calendar'])
            ->group(__DIR__.'/routes/api.php');

        Route::prefix('api/v1/calendar')
            ->middleware(['api', 'throttle:30,1'])
            ->get('google/callback', GoogleCallbackController::class)
            ->name('calendar.google.callback');

        if ($this->app->runningInConsole()) {
            $this->commands([SyncGoogleCalendarsCommand::class]);
        }

        $this->callAfterResolving(Schedule::class, function (Schedule $schedule): void {
            $schedule->command('calendar:sync')->everyFifteenMinutes()->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
        });
    }
}
