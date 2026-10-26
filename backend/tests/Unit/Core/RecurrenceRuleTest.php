<?php

use App\Core\Recurrence\RecurrenceDescriber;
use App\Core\Recurrence\RecurrenceRule;
use Carbon\CarbonImmutable;

function day(string $date): CarbonImmutable
{
    return CarbonImmutable::createFromFormat('!Y-m-d', $date, 'Europe/Madrid');
}

function dates(array $occurrences): array
{
    return array_map(fn (CarbonImmutable $date) => $date->toDateString(), $occurrences);
}

it('expands every frequency the template editor offers', function (string $rule, string $start, array $expected, string $description) {
    $recurrence = RecurrenceRule::parse($rule, day($start));

    expect(dates($recurrence->next(day($start), 3)))->toBe($expected)
        ->and(RecurrenceDescriber::describe($recurrence))->toBe($description);
})->with([
    'every 3 days' => ['FREQ=DAILY;INTERVAL=3', '2026-03-04', ['2026-03-04', '2026-03-07', '2026-03-10'], 'Cada 3 días'],
    'mondays and thursdays' => ['FREQ=WEEKLY;BYDAY=MO,TH', '2026-10-26', ['2026-10-26', '2026-10-29', '2026-11-02'], 'Cada lunes y jueves'],
    'every 2 weeks on saturday' => ['FREQ=WEEKLY;INTERVAL=2;BYDAY=SA', '2026-10-26', ['2026-10-31', '2026-11-14', '2026-11-28'], 'Cada 2 semanas, el sábado'],
    'first of the month' => ['FREQ=MONTHLY;BYMONTHDAY=1', '2026-10-26', ['2026-11-01', '2026-12-01', '2027-01-01'], 'El día 1 de cada mes'],
    'last friday' => ['FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1', '2026-10-26', ['2026-10-30', '2026-11-27', '2026-12-25'], 'El último viernes de cada mes'],
    'last day of month' => ['FREQ=MONTHLY;BYMONTHDAY=-1', '2027-01-15', ['2027-01-31', '2027-02-28', '2027-03-31'], 'El último día de cada mes'],
    'yearly' => ['FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15', '2026-10-26', ['2027-03-15', '2028-03-15', '2029-03-15'], 'Cada 15 de marzo'],
    'weekdays' => ['FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', '2026-10-30', ['2026-10-30', '2026-11-02', '2026-11-03'], 'De lunes a viernes'],
]);

it('honours until and count', function () {
    $until = RecurrenceRule::parse('FREQ=WEEKLY', day('2026-10-26'), until: day('2026-11-09'));
    $count = RecurrenceRule::parse('FREQ=DAILY', day('2026-10-26'), count: 2);

    expect(dates($until->between(day('2026-10-01'), day('2026-12-31'))))->toBe(['2026-10-26', '2026-11-02', '2026-11-09'])
        ->and(dates($count->next(day('2026-10-26'), 5)))->toBe(['2026-10-26', '2026-10-27'])
        ->and(RecurrenceDescriber::ending(day('2026-11-09'), null))->toBe('hasta el 9 nov')
        ->and(RecurrenceDescriber::ending(null, 10))->toBe('10 veces');
});

it('rejects rules outside the supported subset', function (string $rule) {
    expect(RecurrenceRule::isValid($rule))->toBeFalse();
})->with(['', 'FREQ=HOURLY', 'FREQ=DAILY;COUNT=3', 'FREQ=DAILY;INTERVAL=0', 'FREQ=WEEKLY;BYDAY=XX', 'nonsense']);

it('normalises the rule text', function () {
    expect(RecurrenceRule::parse('rrule:byday=mo;freq=weekly', day('2026-10-26'))->toString())->toBe('FREQ=WEEKLY;BYDAY=MO');
});
