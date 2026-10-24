<?php

use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Facades\Schedule;

Schedule::command('queue:prune-failed --hours=168')->daily();

Schedule::call(fn () => DatabaseNotification::query()
    ->whereNotNull('read_at')
    ->where('created_at', '<', now()->subDays(90))
    ->delete())
    ->name('notifications:prune-read')
    ->dailyAt('04:00');
