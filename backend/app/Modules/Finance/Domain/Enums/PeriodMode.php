<?php

namespace App\Modules\Finance\Domain\Enums;

enum PeriodMode: string
{
    case Payroll = 'payroll';

    case Calendar = 'calendar';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
