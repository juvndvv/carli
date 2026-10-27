<?php

namespace App\Modules\Habits\Domain\Enums;

enum PeriodStatus: string
{
    case Met = 'met';

    case Missed = 'missed';

    case Current = 'current';

    case Excused = 'excused';

    case Off = 'off';

    public function isEvaluable(): bool
    {
        return $this === self::Met || $this === self::Missed;
    }
}
