<?php

namespace App\Modules\Tasks\Domain\Enums;

enum TaskStatus: string
{
    case Open = 'open';

    case Done = 'done';

    case Skipped = 'skipped';
}
