<?php

namespace App\Modules\Finance\Domain\Enums;

enum TransactionKind: string
{
    case Expense = 'expense';

    case Income = 'income';

    case Transfer = 'transfer';

    case Adjustment = 'adjustment';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
