<?php

use App\Modules\Finance\FinanceServiceProvider;
use App\Modules\Tasks\TasksServiceProvider;

return [
    'providers' => [
        FinanceServiceProvider::class,
        TasksServiceProvider::class,
    ],
];
