<?php

namespace App\Modules\Tasks\Domain\Enums;

enum SkipReason: string
{
    case Manual = 'manual';

    case Replaced = 'replaced';

    case Missed = 'missed';
}
