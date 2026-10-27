<?php

namespace App\Modules\Habits\Domain\Enums;

enum EntrySource: string
{
    case Manual = 'manual';

    case TaskImport = 'task_import';

    case Health = 'health';
}
