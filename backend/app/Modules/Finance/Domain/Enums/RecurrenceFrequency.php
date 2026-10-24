<?php

namespace App\Modules\Finance\Domain\Enums;

enum RecurrenceFrequency: string
{
    case Daily = 'daily';

    case Weekly = 'weekly';

    case Monthly = 'monthly';

    case Yearly = 'yearly';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
