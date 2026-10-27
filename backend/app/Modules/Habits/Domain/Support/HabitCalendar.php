<?php

namespace App\Modules\Habits\Domain\Support;

use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use InvalidArgumentException;

final class HabitCalendar
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

    public static function localDay(CarbonInterface $moment): CarbonImmutable
    {
        return CarbonImmutable::instance($moment)->setTimezone(self::TIMEZONE)->startOfDay();
    }

    public static function weekStart(CarbonImmutable $day): CarbonImmutable
    {
        return $day->subDays($day->dayOfWeekIso - 1);
    }

    public static function weekEnd(CarbonImmutable $day): CarbonImmutable
    {
        return self::weekStart($day)->addDays(6);
    }

    public static function time(?string $value): ?string
    {
        return $value === null ? null : substr($value, 0, 5);
    }
}
