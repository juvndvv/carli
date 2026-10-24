<?php

namespace App\Modules\Finance\Domain\Enums;

enum ShareMode: string
{
    case Equal = 'equal';

    case Percentage = 'percentage';

    case Amount = 'amount';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
