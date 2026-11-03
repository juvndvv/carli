<?php

namespace App\Modules\Calendar\Domain;

use Carbon\CarbonImmutable;

final class CalendarClock
{
    public const string TIMEZONE = 'Europe/Madrid';

    /** How far back and ahead Google events are copied. */
    public const int PAST_DAYS = 60;

    public const int FUTURE_DAYS = 365;

    public static function today(): CarbonImmutable
    {
        return CarbonImmutable::now(self::TIMEZONE)->startOfDay();
    }

    public static function date(string $value): CarbonImmutable
    {
        return CarbonImmutable::createFromFormat('!Y-m-d', substr($value, 0, 10), self::TIMEZONE) ?: self::today();
    }
}
