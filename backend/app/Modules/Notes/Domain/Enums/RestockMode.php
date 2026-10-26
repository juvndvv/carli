<?php

namespace App\Modules\Notes\Domain\Enums;

enum RestockMode: string
{
    case EveryTrip = 'every_trip';

    case Interval = 'interval';

    case None = 'none';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
