<?php

use App\Modules\Finance\Domain\Enums\RecurrenceFrequency;
use App\Modules\Finance\Domain\Services\RecurrenceSchedule;
use App\Modules\Finance\Domain\Support\SpanishCalendar;

function scheduleDates(RecurrenceSchedule $schedule, string $from, string $to): array
{
    return array_map(fn ($date) => $date->toDateString(), $schedule->between(SpanishCalendar::date($from), SpanishCalendar::date($to)));
}

it('clamps monthly occurrences to the last day of short months', function () {
    $schedule = new RecurrenceSchedule(RecurrenceFrequency::Monthly, 1, SpanishCalendar::date('2026-01-31'));

    expect(scheduleDates($schedule, '2026-01-01', '2026-04-30'))->toBe(['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30']);
});

it('supports intervals, end dates and an explicit day of month', function () {
    $quarterly = new RecurrenceSchedule(RecurrenceFrequency::Monthly, 3, SpanishCalendar::date('2026-01-10'), SpanishCalendar::date('2026-10-01'), 5);

    expect(scheduleDates($quarterly, '2026-01-01', '2027-01-01'))->toBe(['2026-04-05', '2026-07-05']);
});

it('computes weekly, daily and yearly occurrences', function () {
    $weekly = new RecurrenceSchedule(RecurrenceFrequency::Weekly, 2, SpanishCalendar::date('2026-10-05'));
    $daily = new RecurrenceSchedule(RecurrenceFrequency::Daily, 10, SpanishCalendar::date('2026-10-01'));
    $yearly = new RecurrenceSchedule(RecurrenceFrequency::Yearly, 1, SpanishCalendar::date('2024-02-29'));

    expect(scheduleDates($weekly, '2026-10-06', '2026-11-05'))->toBe(['2026-10-19', '2026-11-02'])
        ->and(scheduleDates($daily, '2026-10-01', '2026-10-25'))->toBe(['2026-10-01', '2026-10-11', '2026-10-21'])
        ->and(scheduleDates($yearly, '2025-01-01', '2028-12-31'))->toBe(['2025-02-28', '2026-02-28', '2027-02-28', '2028-02-29']);
});

it('returns the next occurrence after a date', function () {
    $schedule = new RecurrenceSchedule(RecurrenceFrequency::Monthly, 1, SpanishCalendar::date('2026-09-28'));

    expect($schedule->after(SpanishCalendar::date('2026-09-28'))?->toDateString())->toBe('2026-10-28')
        ->and($schedule->first()?->toDateString())->toBe('2026-09-28');
});
