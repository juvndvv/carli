<?php

namespace App\Providers;

use App\Core\Modules\ModuleRegistry;
use App\Core\Pending\PendingRegistry;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(ModuleRegistry::class, fn () => new ModuleRegistry(
            array_values(array_filter((array) config('modules.providers', []), 'is_string')),
        ));

        $this->app->singleton(PendingRegistry::class);

        foreach (config('modules.providers', []) as $provider) {
            $this->app->register($provider);
        }
    }

    public function boot(): void {}
}
