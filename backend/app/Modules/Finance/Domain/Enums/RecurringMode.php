<?php

namespace App\Modules\Finance\Domain\Enums;

enum RecurringMode: string
{
    case Auto = 'auto';

    case Confirm = 'confirm';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
