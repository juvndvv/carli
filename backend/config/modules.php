<?php

use App\Modules\Finance\FinanceServiceProvider;
use App\Modules\Notes\NotesServiceProvider;
use App\Modules\Tasks\TasksServiceProvider;

return [
    'providers' => [
        FinanceServiceProvider::class,
        TasksServiceProvider::class,
        NotesServiceProvider::class,
    ],
];
