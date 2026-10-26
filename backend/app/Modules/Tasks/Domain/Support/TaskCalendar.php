<?php

namespace App\Modules\Tasks\Domain\Support;

use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use InvalidArgumentException;

final class TaskCalendar
{
    public const string TIMEZONE = 'Europe/Madrid';

    public static function today(): CarbonImmutable
    {
        return CarbonImmutable::now(self::TIMEZONE)->startOfDay();
    }

    public static function date(string|CarbonInterface $value): CarbonImmutable
    {
        $text = $value instanceof CarbonInterface ? $value->format('Y-m-d') : substr($value, 0, 10);
        $date = CarbonImmutable::createFromFormat('!Y-m-d', $text, self::TIMEZONE);

        if (! $date instanceof CarbonImmutable) {
            throw new InvalidArgumentException("Invalid date [{$text}].");
        }

        return $date;
    }

    public static function time(?string $value): ?string
    {
        return $value === null ? null : substr($value, 0, 5);
    }
}
