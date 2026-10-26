<?php

namespace App\Modules\Notes;

use App\Core\Search\ModuleSearcher;
use App\Modules\Notes\Domain\Services\DefaultSections;
use App\Modules\Notes\Domain\Services\RestockService;
use App\Modules\Notes\Domain\Services\SyncService;
use App\Modules\Notes\Http\Middleware\EnsureNotesInitialized;
use App\Modules\Notes\Queries\NoteSearch;
use App\Modules\Notes\Queries\SnapshotQuery;
use App\Modules\Notes\Search\NotesSearcher;
use Illuminate\Foundation\Http\Middleware\ConvertEmptyStringsToNull;
use Illuminate\Foundation\Http\Middleware\TrimStrings;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class NotesServiceProvider extends ServiceProvider
{
    public const string TIMEZONE = 'Europe/Madrid';

    private const array SCOPED_SERVICES = [
        DefaultSections::class,
        RestockService::class,
        SyncService::class,
        SnapshotQuery::class,
        NoteSearch::class,
    ];

    public static function manifestPath(): string
    {
        return __DIR__.'/module.php';
    }

    public function register(): void
    {
        foreach (self::SCOPED_SERVICES as $service) {
            $this->app->scoped($service);
        }

        $this->app->tag([NotesSearcher::class], ModuleSearcher::TAG);
    }

    public function boot(): void
    {
        $this->loadMigrationsFrom(__DIR__.'/database/migrations');

        Route::prefix('api/v1/notes')
            ->middleware(['api', 'auth:sanctum', 'module:notes', EnsureNotesInitialized::class])
            ->group(__DIR__.'/routes/api.php');

        $isSync = fn (Request $request): bool => $request->is('api/v1/notes/sync');
        ConvertEmptyStringsToNull::skipWhen($isSync);
        TrimStrings::skipWhen($isSync);
    }
}
