<?php

namespace App\Modules\Finance\Domain\Enums;

enum PeriodOpenedBy: string
{
    case Payroll = 'payroll';

    case Manual = 'manual';

    case Calendar = 'calendar';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
