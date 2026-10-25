<?php

namespace App\Modules\Finance\Domain\Enums;

enum BankConnectionStatus: string
{
    case Active = 'active';

    case Expired = 'expired';

    case Revoked = 'revoked';

    case Error = 'error';

    public function isSyncable(): bool
    {
        return $this === self::Active || $this === self::Error;
    }
}
