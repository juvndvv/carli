<?php

namespace App\Modules\Finance\Domain\Enums;

enum AccountType: string
{
    case Checking = 'checking';

    case Savings = 'savings';

    case CreditCard = 'credit_card';

    case Cash = 'cash';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
