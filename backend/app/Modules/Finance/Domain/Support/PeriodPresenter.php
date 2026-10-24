<?php

namespace App\Modules\Finance\Domain\Support;

use App\Modules\Finance\Models\Period;
use Carbon\CarbonImmutable;

final class PeriodPresenter
{
    public static function majorityMonth(Period $period): CarbonImmutable
    {
        $end = $period->effectiveEndDate();
        $daysByMonth = [];
        $cursor = $period->start_date->startOfMonth();

        while ($cursor->lessThanOrEqualTo($end)) {
            $monthStart = $cursor->max($period->start_date);
            $monthEnd = $cursor->endOfMonth()->startOfDay()->min($end);
            $daysByMonth[$cursor->format('Y-m')] = (int) $monthStart->diffInDays($monthEnd) + 1;
            $cursor = $cursor->addMonthNoOverflow();
        }

        $bestMonth = $period->start_date->format('Y-m');
        $bestDays = -1;
        foreach ($daysByMonth as $month => $days) {
            if ($days >= $bestDays) {
                $bestMonth = $month;
                $bestDays = $days;
            }
        }

        return SpanishCalendar::date($bestMonth.'-01');
    }

    public static function name(Period $period): string
    {
        $month = self::majorityMonth($period);
        $name = 'Periodo de '.SpanishCalendar::monthName($month->month);

        if ($month->year !== SpanishCalendar::today()->year) {
            $name .= ' de '.$month->year;
        }

        return $name;
    }

    public static function shortName(Period $period): string
    {
        $month = self::majorityMonth($period);

        return SpanishCalendar::shortMonthName($month->month);
    }

    public static function rangeLabel(Period $period): string
    {
        return SpanishCalendar::shortDate($period->start_date).' – '.SpanishCalendar::shortDate($period->effectiveEndDate());
    }

    public static function label(Period $period): string
    {
        return self::name($period).' ('.self::rangeLabel($period).')';
    }

    public static function totalDays(Period $period): int
    {
        return (int) $period->start_date->diffInDays($period->effectiveEndDate()) + 1;
    }

    public static function elapsedDays(Period $period, ?CarbonImmutable $today = null): int
    {
        $today ??= SpanishCalendar::today();

        if ($today->lessThan($period->start_date)) {
            return 0;
        }

        $last = $today->min($period->effectiveEndDate());

        return (int) $period->start_date->diffInDays($last) + 1;
    }

    public static function remainingDays(Period $period, ?CarbonImmutable $today = null): int
    {
        $today ??= SpanishCalendar::today();
        $end = $period->effectiveEndDate();

        if ($today->greaterThan($end)) {
            return 0;
        }

        return (int) $today->max($period->start_date)->diffInDays($end) + 1;
    }
}
