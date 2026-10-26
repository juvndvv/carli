<?php

namespace App\Core\Recurrence;

use Carbon\CarbonImmutable;

final class RecurrenceDescriber
{
    private const array WEEKDAYS = [
        'MO' => 'lunes', 'TU' => 'martes', 'WE' => 'miércoles', 'TH' => 'jueves', 'FR' => 'viernes', 'SA' => 'sábado', 'SU' => 'domingo',
    ];

    private const array MONTHS = [
        1 => 'enero', 2 => 'febrero', 3 => 'marzo', 4 => 'abril', 5 => 'mayo', 6 => 'junio',
        7 => 'julio', 8 => 'agosto', 9 => 'septiembre', 10 => 'octubre', 11 => 'noviembre', 12 => 'diciembre',
    ];

    private const array SHORT_MONTHS = [
        1 => 'ene', 2 => 'feb', 3 => 'mar', 4 => 'abr', 5 => 'may', 6 => 'jun',
        7 => 'jul', 8 => 'ago', 9 => 'sep', 10 => 'oct', 11 => 'nov', 12 => 'dic',
    ];

    private const array POSITIONS = [1 => 'primer', 2 => 'segundo', 3 => 'tercer', 4 => 'cuarto', 5 => 'quinto', -1 => 'último', -2 => 'penúltimo'];

    public static function describe(RecurrenceRule $rule): string
    {
        $interval = $rule->interval();

        return match ($rule->frequency()) {
            'DAILY' => $interval === 1 ? 'Cada día' : "Cada {$interval} días",
            'WEEKLY' => self::weekly($rule, $interval),
            'MONTHLY' => self::monthly($rule, $interval),
            default => self::yearly($rule, $interval),
        };
    }

    public static function afterDone(int $days): string
    {
        return $days === 1 ? '1 día después de completarla' : "{$days} días después de completarla";
    }

    public static function ending(?CarbonImmutable $until, ?int $count): ?string
    {
        return match (true) {
            $until !== null => 'hasta el '.self::shortDate($until),
            $count !== null => $count === 1 ? '1 vez' : "{$count} veces",
            default => null,
        };
    }

    public static function shortDate(CarbonImmutable $date): string
    {
        return $date->day.' '.self::SHORT_MONTHS[$date->month];
    }

    private static function weekly(RecurrenceRule $rule, int $interval): string
    {
        $days = self::weekdays($rule->part('BYDAY')) ?: [self::weekdayCode($rule->start)];

        if (count($days) === 7 && $interval === 1) {
            return 'Cada día';
        }

        if ($days === ['MO', 'TU', 'WE', 'TH', 'FR'] && $interval === 1) {
            return 'De lunes a viernes';
        }

        $names = self::join(array_map(fn (string $day) => self::WEEKDAYS[$day], $days));

        if ($interval === 1) {
            return 'Cada '.$names;
        }

        return "Cada {$interval} semanas, ".(count($days) === 1 ? 'el ' : 'los ').$names;
    }

    private static function monthly(RecurrenceRule $rule, int $interval): string
    {
        $every = $interval === 1 ? 'de cada mes' : "cada {$interval} meses";
        $byDay = $rule->part('BYDAY');
        $position = $rule->part('BYSETPOS');

        if ($byDay !== null) {
            if (preg_match('/^([+-]?\d)(MO|TU|WE|TH|FR|SA|SU)$/', $byDay, $match) === 1) {
                $position = $match[1];
                $byDay = $match[2];
            }

            $days = self::weekdays($byDay);
            if (count($days) === 1 && $position !== null && isset(self::POSITIONS[(int) $position])) {
                return 'El '.self::POSITIONS[(int) $position].' '.self::WEEKDAYS[$days[0]].' '.$every;
            }
        }

        $monthDays = array_map('intval', explode(',', $rule->part('BYMONTHDAY') ?? (string) $rule->start->day));

        if ($monthDays === [-1]) {
            return 'El último día '.$every;
        }

        $labels = array_map(fn (int $day) => $day < 0 ? 'último' : (string) $day, $monthDays);

        return (count($labels) === 1 ? 'El día ' : 'Los días ').self::join($labels).' '.$every;
    }

    private static function yearly(RecurrenceRule $rule, int $interval): string
    {
        $month = (int) ($rule->part('BYMONTH') ?? $rule->start->month);
        $day = (int) ($rule->part('BYMONTHDAY') ?? $rule->start->day);
        $date = ($day === -1 ? 'último día de ' : $day.' de ').(self::MONTHS[$month] ?? '');

        return $interval === 1 ? 'Cada '.$date : "Cada {$interval} años, el {$date}";
    }

    /**
     * @return list<string>
     */
    private static function weekdays(?string $value): array
    {
        if ($value === null) {
            return [];
        }

        $selected = array_map(fn (string $day) => substr($day, -2), explode(',', $value));

        return array_values(array_filter(array_keys(self::WEEKDAYS), fn (string $day) => in_array($day, $selected, true)));
    }

    private static function weekdayCode(CarbonImmutable $date): string
    {
        return array_keys(self::WEEKDAYS)[$date->dayOfWeekIso - 1];
    }

    /**
     * @param  list<string>  $items
     */
    private static function join(array $items): string
    {
        if (count($items) <= 1) {
            return $items[0] ?? '';
        }

        $last = array_pop($items);

        return implode(', ', $items).' y '.$last;
    }
}
