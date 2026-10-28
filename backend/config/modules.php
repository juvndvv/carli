<?php

use App\Modules\Finance\FinanceServiceProvider;
use App\Modules\Habits\HabitsServiceProvider;
use App\Modules\Health\HealthServiceProvider;
use App\Modules\Notes\NotesServiceProvider;
use App\Modules\Tasks\TasksServiceProvider;

return [
    'providers' => [
        FinanceServiceProvider::class,
        TasksServiceProvider::class,
        NotesServiceProvider::class,
        HabitsServiceProvider::class,
        HealthServiceProvider::class,
    ],
];
