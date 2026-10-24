<?php

namespace App\Modules\Finance\Domain\Enums;

enum CategoryKind: string
{
    case Expense = 'expense';

    case Income = 'income';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
