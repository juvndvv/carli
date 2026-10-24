<?php

namespace Tests\Feature\Core\Fixtures\Journal;

use App\Core\Modules\ModuleRegistry;
use Illuminate\Contracts\Foundation\Application;

final class JournalModule
{
    public static function register(Application $app): void
    {
        $app->forgetInstance(ModuleRegistry::class);
        $app->singleton(ModuleRegistry::class, fn () => new ModuleRegistry([JournalServiceProvider::class]));
    }
}
