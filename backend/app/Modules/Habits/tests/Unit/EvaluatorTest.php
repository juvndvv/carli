<?php

use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Enums\PeriodStatus;
use App\Modules\Habits\Domain\Evaluation\Goal;
use App\Modules\Habits\Domain\Evaluation\HabitEvaluator;
use App\Modules\Habits\Domain\Evaluation\HabitStats;
use App\Modules\Habits\Domain\Evaluation\Period;
use App\Modules\Habits\Domain\Evaluation\Timeline;
use App\Modules\Habits\Domain\Support\GoalDescriber;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use Carbon\CarbonImmutable;

function habitDay(string $date): CarbonImmutable
{
    return HabitCalendar::date($date);
}

/**
 * @param  list<array{0: string, 1: string, 2?: float, 3?: list<int>|null}>  $goals
 * @param  array<string, float>  $values
 * @param  list<array{0: string, 1: string}>  $breaks
 */
function habitTimeline(HabitKind $kind, string $start, array $goals, array $values = [], array $breaks = [], ?string $stop = null): Timeline
{
    return new Timeline(
        $kind,
        habitDay($start),
        $stop === null ? null : habitDay($stop),
        array_map(fn (array $goal) => new Goal(habitDay($goal[0]), GoalPeriod::from($goal[1]), $goal[2] ?? 1.0, $goal[3] ?? null), $goals),
        $values,
        array_map(fn (array $range) => [habitDay($range[0]), habitDay($range[1])], $breaks),
    );
}

/**
 * @return list<Period>
 */
function habitPeriods(Timeline $timeline, string $today): array
{
    return (new HabitEvaluator)->periods($timeline, habitDay($today));
}

/**
 * @param  list<Period>  $periods
 * @return array<string, string>
 */
function habitStatuses(array $periods): array
{
    $statuses = [];
    foreach ($periods as $period) {
        $statuses[$period->start->toDateString()] = $period->status->value;
    }

    return $statuses;
}

describe('daily yes/no', function () {
    it('marks logged days as met, empty past days as missed and today as in progress', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-22', [['2026-10-22', 'day']], ['2026-10-22' => 1, '2026-10-24' => 1, '2026-10-25' => 1]), '2026-10-27');

        expect(habitStatuses($periods))->toBe([
            '2026-10-22' => 'met',
            '2026-10-23' => 'missed',
            '2026-10-24' => 'met',
            '2026-10-25' => 'met',
            '2026-10-26' => 'missed',
            '2026-10-27' => 'current',
        ]);
    });

    it('keeps the streak while today is still open and adds today once it is met', function () {
        $values = ['2026-10-24' => 1, '2026-10-25' => 1, '2026-10-26' => 1];
        $open = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-20', [['2026-10-20', 'day']], $values), '2026-10-27');
        $done = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-20', [['2026-10-20', 'day']], $values + ['2026-10-27' => 1]), '2026-10-27');

        expect(HabitStats::streak($open))->toBe(3)
            ->and(HabitStats::streak($done))->toBe(4);
    });

    it('breaks the streak with a missed day', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-20', [['2026-10-20', 'day']], ['2026-10-20' => 1, '2026-10-21' => 1, '2026-10-22' => 1, '2026-10-24' => 1]), '2026-10-25');

        expect(HabitStats::streak($periods))->toBe(1)
            ->and(HabitStats::bestStreak($periods))->toMatchArray(['length' => 3])
            ->and(HabitStats::bestStreak($periods)['end']?->toDateString())->toBe('2026-10-22');
    });

    it('produces nothing before the start date', function () {
        expect(habitPeriods(habitTimeline(HabitKind::Check, '2026-10-28', [['2026-10-28', 'day']]), '2026-10-27'))->toBe([]);
    });
});

describe('specific days', function () {
    it('only evaluates the marked days and ignores entries on the others', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-19', [['2026-10-19', 'day', 1, [1, 3, 5]]], ['2026-10-19' => 1, '2026-10-20' => 1, '2026-10-23' => 1]), '2026-10-25');

        expect(habitStatuses($periods))->toBe([
            '2026-10-19' => 'met',
            '2026-10-20' => 'off',
            '2026-10-21' => 'missed',
            '2026-10-22' => 'off',
            '2026-10-23' => 'met',
            '2026-10-24' => 'off',
            '2026-10-25' => 'off',
        ])->and(HabitStats::tally($periods))->toBe(['met' => 2, 'total' => 3]);
    });

    it('skips unmarked days without breaking the streak', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-19', [['2026-10-19', 'day', 1, [1, 3, 5]]], ['2026-10-19' => 1, '2026-10-21' => 1, '2026-10-23' => 1, '2026-10-26' => 1]), '2026-10-27');

        expect(HabitStats::streak($periods))->toBe(4);
    });
});

describe('times per week', function () {
    it('asks for the full target on complete weeks', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-12', [['2026-10-12', 'week', 3]], ['2026-10-12' => 1, '2026-10-14' => 1, '2026-10-19' => 1]), '2026-10-27');

        expect(array_map(fn (Period $period) => [$period->start->toDateString(), $period->end->toDateString(), $period->target, $period->value, $period->status->value], $periods))->toBe([
            ['2026-10-12', '2026-10-18', 3.0, 2.0, 'missed'],
            ['2026-10-19', '2026-10-25', 3.0, 1.0, 'missed'],
            ['2026-10-26', '2026-11-01', 3.0, 0.0, 'current'],
        ]);
    });

    it('prorates the first week to the days that are left', function (string $start, float $target) {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, $start, [[$start, 'week', 3]]), '2026-11-01');

        expect($periods[0]->target)->toBe($target)
            ->and($periods[0]->start->toDateString())->toBe($start)
            ->and($periods[0]->end->toDateString())->toBe('2026-11-01');
    })->with([
        'monday' => ['2026-10-26', 3.0],
        'thursday' => ['2026-10-29', 3.0],
        'saturday' => ['2026-10-31', 2.0],
        'sunday' => ['2026-11-01', 1.0],
    ]);

    it('counts days with an entry, not the values', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-19', [['2026-10-19', 'week', 2]], ['2026-10-19' => 5]), '2026-10-26');

        expect($periods[0]->value)->toBe(1.0)
            ->and($periods[0]->status)->toBe(PeriodStatus::Missed);
    });

    it('marks the current week as met as soon as the target is reached', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-19', [['2026-10-19', 'week', 2]], ['2026-10-19' => 1, '2026-10-20' => 1, '2026-10-26' => 1, '2026-10-27' => 1]), '2026-10-27');

        expect(end($periods)->status)->toBe(PeriodStatus::Met)
            ->and(HabitStats::streak($periods))->toBe(2);
    });

    it('does not break the streak while the current week is open', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-19', [['2026-10-19', 'week', 2]], ['2026-10-19' => 1, '2026-10-20' => 1]), '2026-10-27');

        expect(end($periods)->status)->toBe(PeriodStatus::Current)
            ->and(HabitStats::streak($periods))->toBe(1);
    });
});

describe('quantities', function () {
    it('meets a day when the value reaches the target', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Quantity, '2026-10-25', [['2026-10-25', 'day', 8]], ['2026-10-25' => 5, '2026-10-26' => 8, '2026-10-27' => 3]), '2026-10-27');

        expect(habitStatuses($periods))->toBe(['2026-10-25' => 'missed', '2026-10-26' => 'met', '2026-10-27' => 'current']);
    });

    it('sums the week and prorates a partial first week by days', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Quantity, '2026-10-22', [['2026-10-22', 'week', 140]], ['2026-10-22' => 30, '2026-10-24' => 50, '2026-10-26' => 100, '2026-10-27' => 45]), '2026-10-27');

        expect($periods[0]->target)->toBe(80.0)
            ->and($periods[0]->value)->toBe(80.0)
            ->and($periods[0]->status)->toBe(PeriodStatus::Met)
            ->and($periods[1]->target)->toBe(140.0)
            ->and($periods[1]->value)->toBe(145.0)
            ->and($periods[1]->status)->toBe(PeriodStatus::Met);
    });
});

describe('avoid', function () {
    it('counts a day without entries as met and today as in progress', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Avoid, '2026-10-20', [['2026-10-20', 'day', 0]], ['2026-10-22' => 1]), '2026-10-27');

        expect(habitStatuses($periods))->toBe([
            '2026-10-20' => 'met',
            '2026-10-21' => 'met',
            '2026-10-22' => 'missed',
            '2026-10-23' => 'met',
            '2026-10-24' => 'met',
            '2026-10-25' => 'met',
            '2026-10-26' => 'met',
            '2026-10-27' => 'current',
        ])->and(HabitStats::streak($periods))->toBe(4);
    });

    it('misses today as soon as the maximum is exceeded', function () {
        $within = habitPeriods(habitTimeline(HabitKind::Avoid, '2026-10-27', [['2026-10-27', 'day', 2]], ['2026-10-27' => 2]), '2026-10-27');
        $over = habitPeriods(habitTimeline(HabitKind::Avoid, '2026-10-27', [['2026-10-27', 'day', 2]], ['2026-10-27' => 3]), '2026-10-27');

        expect($within[0]->status)->toBe(PeriodStatus::Current)
            ->and($over[0]->status)->toBe(PeriodStatus::Missed);
    });

    it('limits a week without prorating the maximum', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Avoid, '2026-10-22', [['2026-10-22', 'week', 2]], ['2026-10-22' => 1, '2026-10-24' => 1, '2026-10-26' => 2, '2026-10-27' => 1]), '2026-10-27');

        expect($periods[0]->target)->toBe(2.0)
            ->and($periods[0]->status)->toBe(PeriodStatus::Met)
            ->and($periods[1]->status)->toBe(PeriodStatus::Missed);
    });
});

describe('breaks', function () {
    it('excuses days on break without breaking the streak', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-20', [['2026-10-20', 'day']], ['2026-10-20' => 1, '2026-10-21' => 1, '2026-10-25' => 1, '2026-10-26' => 1], [['2026-10-22', '2026-10-24']]), '2026-10-27');

        expect(array_count_values(habitStatuses($periods)))->toBe(['met' => 4, 'excused' => 3, 'current' => 1])
            ->and(HabitStats::streak($periods))->toBe(4)
            ->and(HabitStats::tally($periods))->toBe(['met' => 4, 'total' => 4]);
    });

    it('excuses a whole week on break and lowers the target of a partial one', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-12', [['2026-10-12', 'week', 3]], ['2026-10-24' => 1, '2026-10-25' => 1], [['2026-10-12', '2026-10-18'], ['2026-10-19', '2026-10-23']]), '2026-10-26');

        expect($periods[0]->status)->toBe(PeriodStatus::Excused)
            ->and($periods[1]->target)->toBe(2.0)
            ->and($periods[1]->status)->toBe(PeriodStatus::Met);
    });
});

describe('goal history', function () {
    it('evaluates past days with the goal they had', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Quantity, '2026-10-20', [['2026-10-20', 'day', 8], ['2026-10-26', 'day', 5]], ['2026-10-24' => 6, '2026-10-25' => 6, '2026-10-26' => 6]), '2026-10-27');

        expect(habitStatuses($periods))->toMatchArray(['2026-10-24' => 'missed', '2026-10-25' => 'missed', '2026-10-26' => 'met'])
            ->and($periods[4]->target)->toBe(8.0)
            ->and($periods[6]->target)->toBe(5.0);
    });

    it('switches from days to a weekly goal in the middle of a week', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-19', [['2026-10-19', 'day'], ['2026-10-22', 'week', 3]], ['2026-10-19' => 1, '2026-10-22' => 1, '2026-10-24' => 1]), '2026-10-27');

        expect(array_map(fn (Period $period) => [$period->period->value, $period->start->toDateString(), $period->end->toDateString(), $period->target, $period->status->value], $periods))->toBe([
            ['day', '2026-10-19', '2026-10-19', 1.0, 'met'],
            ['day', '2026-10-20', '2026-10-20', 1.0, 'missed'],
            ['day', '2026-10-21', '2026-10-21', 1.0, 'missed'],
            ['week', '2026-10-22', '2026-10-25', 3.0, 'missed'],
            ['week', '2026-10-26', '2026-11-01', 3.0, 'current'],
        ]);
    });

    it('closes a weekly goal when switching back to days', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-19', [['2026-10-19', 'week', 2], ['2026-10-22', 'day']], ['2026-10-19' => 1, '2026-10-20' => 1, '2026-10-22' => 1]), '2026-10-22');

        expect(array_map(fn (Period $period) => [$period->period->value, $period->start->toDateString(), $period->end->toDateString(), $period->target, $period->status->value], $periods))->toBe([
            ['week', '2026-10-19', '2026-10-21', 2.0, 'met'],
            ['day', '2026-10-22', '2026-10-22', 1.0, 'met'],
        ]);
    });
});

describe('consistency', function () {
    it('uses the last four closed weeks plus the current period only when met', function () {
        $values = [];
        for ($date = habitDay('2026-09-21'); $date->lte(habitDay('2026-10-26')); $date = $date->addDay()) {
            $values[$date->toDateString()] = 1.0;
        }
        unset($values['2026-09-22'], $values['2026-10-01'], $values['2026-10-02']);

        $timeline = habitTimeline(HabitKind::Check, '2026-09-21', [['2026-09-21', 'day']], $values);
        $open = habitPeriods($timeline, '2026-10-27');

        expect(HabitStats::windowStart(habitDay('2026-10-27'))->toDateString())->toBe('2026-09-28')
            ->and(HabitStats::tally($open, HabitStats::windowStart(habitDay('2026-10-27'))))->toBe(['met' => 27, 'total' => 29])
            ->and(HabitStats::consistency($open, habitDay('2026-10-27')))->toBe(93);

        $met = habitPeriods(habitTimeline(HabitKind::Check, '2026-09-21', [['2026-09-21', 'day']], $values + ['2026-10-27' => 1.0]), '2026-10-27');

        expect(HabitStats::tally($met, HabitStats::windowStart(habitDay('2026-10-27'))))->toBe(['met' => 28, 'total' => 30]);
    });

    it('has no consistency without evaluable periods', function () {
        expect(HabitStats::consistency(habitPeriods(habitTimeline(HabitKind::Check, '2026-10-27', [['2026-10-27', 'day']]), '2026-10-27'), habitDay('2026-10-27')))->toBeNull();
    });
});

describe('paused habits', function () {
    it('stops evaluating from the day it was paused', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-20', [['2026-10-20', 'day']], ['2026-10-20' => 1], stop: '2026-10-22'), '2026-10-27');

        expect(habitStatuses($periods))->toBe(['2026-10-20' => 'met', '2026-10-21' => 'missed']);
    });

    it('closes the week it was paused in with the days that were tracked', function () {
        $periods = habitPeriods(habitTimeline(HabitKind::Check, '2026-10-26', [['2026-10-26', 'week', 3]], ['2026-10-26' => 1], stop: '2026-10-28'), '2026-10-29');

        expect($periods[0]->target)->toBe(2.0)
            ->and($periods[0]->status)->toBe(PeriodStatus::Missed);
    });
});

describe('goal text', function () {
    it('describes each kind of goal', function (HabitKind $kind, ?string $unit, string $period, float $target, ?array $days, string $text) {
        expect(GoalDescriber::describe($kind, $unit, new Goal(habitDay('2026-10-27'), GoalPeriod::from($period), $target, $days)))->toBe($text);
    })->with([
        [HabitKind::Check, null, 'day', 1, null, 'Cada día'],
        [HabitKind::Check, null, 'day', 1, [1, 3, 5], 'Lunes, miércoles y viernes'],
        [HabitKind::Check, null, 'day', 1, [1, 2, 3, 4, 5], 'De lunes a viernes'],
        [HabitKind::Check, null, 'week', 3, null, '3 veces por semana'],
        [HabitKind::Check, null, 'week', 1, null, '1 vez por semana'],
        [HabitKind::Quantity, 'vasos', 'day', 8, null, '8 vasos al día'],
        [HabitKind::Quantity, 'min', 'week', 150, null, '150 min a la semana'],
        [HabitKind::Quantity, 'km', 'day', 2.5, [6, 7], '2,5 km al día · fines de semana'],
        [HabitKind::Avoid, null, 'day', 0, null, 'Nada'],
        [HabitKind::Avoid, 'cafés', 'day', 2, null, 'Máximo 2 cafés al día'],
        [HabitKind::Avoid, 'cervezas', 'week', 2, null, 'Máximo 2 cervezas por semana'],
    ]);
});
