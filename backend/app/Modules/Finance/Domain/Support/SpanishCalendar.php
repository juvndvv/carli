<?php

namespace App\Modules\Finance\Domain\Support;

use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use InvalidArgumentException;

final class SpanishCalendar
{
    public const string TIMEZONE = 'Europe/Madrid';

    private const array MONTHS = [
        1 => 'enero', 2 => 'febrero', 3 => 'marzo', 4 => 'abril', 5 => 'mayo', 6 => 'junio',
        7 => 'julio', 8 => 'agosto', 9 => 'septiembre', 10 => 'octubre', 11 => 'noviembre', 12 => 'diciembre',
    ];

    private const array SHORT_MONTHS = [
        1 => 'ene', 2 => 'feb', 3 => 'mar', 4 => 'abr', 5 => 'may', 6 => 'jun',
        7 => 'jul', 8 => 'ago', 9 => 'sep', 10 => 'oct', 11 => 'nov', 12 => 'dic',
    ];

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

    public static function monthName(int $month): string
    {
        return self::MONTHS[$month];
    }

    public static function shortMonthName(int $month): string
    {
        return self::SHORT_MONTHS[$month];
    }

    public static function shortDate(CarbonInterface $date): string
    {
        return $date->day.' '.self::shortMonthName($date->month);
    }

    public static function longDate(CarbonInterface $date): string
    {
        return $date->day.' de '.self::monthName($date->month);
    }
}
