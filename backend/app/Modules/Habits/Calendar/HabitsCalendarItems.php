<?php

namespace App\Modules\Habits\Calendar;

use App\Core\Calendar\CalendarItem;
use App\Core\Calendar\CalendarItemsProvider;
use App\Models\User;
use App\Modules\Habits\Domain\Services\HabitReport;
use App\Modules\Habits\Domain\Services\HabitsSettings;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use Carbon\CarbonImmutable;

/**
 * One all-day line per day up to today with how many of that day's habits were met ("3 de 5").
 * Habits are not events, so future days get nothing.
 */
final readonly class HabitsCalendarItems implements CalendarItemsProvider
{
    public const string SOURCE = 'habits';

    private const array COUNTED = ['done', 'miss', 'today'];

    public function __construct(private HabitReport $report) {}

    public function moduleId(): string
    {
        return HabitsSettings::MODULE;
    }

    public function items(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $today = HabitCalendar::today();
        $start = HabitCalendar::date($from);
        $end = HabitCalendar::date($to)->min($today);

        if ($end->lt($start)) {
            return [];
        }

        $breaks = $this->report->globalBreaks($user->id);
        /** @var array<string, array{done: int, total: int}> $days */
        $days = [];

        foreach ($this->report->habits($user) as $habit) {
            $timeline = $this->report->timeline($habit, $breaks);
            $index = $this->report->index($this->report->periods($habit, $today, $breaks));

            for ($day = $start; $day->lte($end); $day = $day->addDay()) {
                $state = $this->report->dayState($timeline, $index, $day, $today);

                if (! in_array($state, self::COUNTED, true)) {
                    continue;
                }

                $key = $day->toDateString();
                $days[$key] ??= ['done' => 0, 'total' => 0];
                $days[$key]['total']++;
                $days[$key]['done'] += $state === 'done' ? 1 : 0;
            }
        }

        $items = [];

        foreach ($days as $key => $count) {
            $date = HabitCalendar::date($key);
            $items[] = new CalendarItem(
                source: self::SOURCE,
                id: 'habits:'.$key,
                title: 'Hábitos',
                date: $date,
                done: $count['done'] === $count['total'],
                subtitle: "{$count['done']} de {$count['total']}",
                url: $date->eq($today) ? '/habitos/hoy' : '/habitos/progreso',
                meta: $count,
            );
        }

        return $items;
    }
}
