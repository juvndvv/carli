<?php

namespace App\Modules\Finance\Domain\Enums;

enum BudgetStatus: string
{
    case Ok = 'ok';

    case Warning = 'warning';

    case Exceeded = 'exceeded';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
