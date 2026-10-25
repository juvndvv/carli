<?php

namespace App\Modules\Finance\Domain\Enums;

enum TransactionSource: string
{
    case Manual = 'manual';

    case Recurring = 'recurring';

    case Bank = 'bank';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
