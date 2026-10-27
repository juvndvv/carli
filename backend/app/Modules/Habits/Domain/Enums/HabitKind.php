<?php

namespace App\Modules\Habits\Domain\Enums;

enum HabitKind: string
{
    case Check = 'check';

    case Quantity = 'quantity';

    case Avoid = 'avoid';
}
