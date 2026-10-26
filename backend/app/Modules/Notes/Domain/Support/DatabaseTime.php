<?php

namespace App\Modules\Notes\Domain\Support;

use Carbon\CarbonInterface;

final class DatabaseTime
{
    public const string FORMAT = 'Y-m-d H:i:s.uP';

    public static function format(CarbonInterface $moment): string
    {
        return $moment->format(self::FORMAT);
    }
}
