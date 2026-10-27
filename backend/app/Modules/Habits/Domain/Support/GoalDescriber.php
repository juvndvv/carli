<?php

namespace App\Modules\Habits\Domain\Support;

use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Evaluation\Goal;

final class GoalDescriber
{
    private const array WEEKDAYS = [1 => 'lunes', 2 => 'martes', 3 => 'miércoles', 4 => 'jueves', 5 => 'viernes', 6 => 'sábado', 7 => 'domingo'];

    public static function describe(HabitKind $kind, ?string $unit, Goal $goal): string
    {
        $amount = self::amount($goal->target, $unit);
        $weekly = $goal->period === GoalPeriod::Week;

        $text = match ($kind) {
            HabitKind::Check => $weekly ? self::times((int) $goal->target) : 'Cada día',
            HabitKind::Quantity => $amount.($weekly ? ' a la semana' : ' al día'),
            HabitKind::Avoid => $goal->target <= 0
                ? ($weekly ? 'Nada en toda la semana' : 'Nada')
                : 'Máximo '.$amount.($weekly ? ' por semana' : ' al día'),
        };

        if ($goal->daysOfWeek === null || $weekly) {
            return $text;
        }

        $days = self::days($goal->daysOfWeek);

        return $kind === HabitKind::Check ? ucfirst($days) : "{$text} · {$days}";
    }

    public static function number(float $value): string
    {
        if (abs($value - round($value)) < 0.005) {
            return (string) (int) round($value);
        }

        return rtrim(rtrim(number_format($value, 2, ',', ''), '0'), ',');
    }

    public static function amount(float $value, ?string $unit): string
    {
        $unit = trim((string) $unit);

        return self::number($value).($unit === '' ? '' : " {$unit}");
    }

    /**
     * @param  list<int>  $days
     */
    public static function days(array $days): string
    {
        sort($days);

        if ($days === [1, 2, 3, 4, 5]) {
            return 'de lunes a viernes';
        }

        if ($days === [6, 7]) {
            return 'fines de semana';
        }

        $names = array_map(fn (int $day) => self::WEEKDAYS[$day], $days);
        $last = (string) array_pop($names);

        return $names === [] ? $last : implode(', ', $names).' y '.$last;
    }

    private static function times(int $times): string
    {
        return $times === 1 ? '1 vez por semana' : "{$times} veces por semana";
    }
}
