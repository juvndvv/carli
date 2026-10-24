<?php

namespace App\Modules\Finance\Domain\Enums;

enum TransactionStatus: string
{
    case Pending = 'pending';

    case Cleared = 'cleared';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
