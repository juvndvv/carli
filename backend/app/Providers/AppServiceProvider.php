<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        foreach (config('modules.providers', []) as $provider) {
            $this->app->register($provider);
        }
    }

    public function boot(): void {}
}
