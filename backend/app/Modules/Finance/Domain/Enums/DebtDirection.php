<?php

namespace App\Modules\Finance\Domain\Enums;

enum DebtDirection: string
{
    case IOwe = 'i_owe';

    case OwedToMe = 'owed_to_me';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
