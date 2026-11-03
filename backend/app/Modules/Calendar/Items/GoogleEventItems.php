<?php

namespace App\Modules\Calendar\Items;

use App\Core\Calendar\CalendarItem;
use App\Core\Calendar\CalendarItemsProvider;
use App\Models\User;
use App\Modules\Calendar\CalendarServiceProvider;
use App\Modules\Calendar\Models\CalendarEvent;
use Carbon\CarbonImmutable;

/**
 * Google events of the selected calendars, one item per day they cover (a three-day trip shows on each day).
 */
final class GoogleEventItems implements CalendarItemsProvider
{
    public const string SOURCE = 'google';

    public function moduleId(): string
    {
        return CalendarServiceProvider::MODULE;
    }

    public function items(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $events = CalendarEvent::query()->ownedBy($user)
            ->overlapping($from, $to)
            ->whereHas('calendar', fn ($calendar) => $calendar->where('selected', true))
            ->with('calendar.account')
            ->get();

        $items = [];

        foreach ($events as $event) {
            array_push($items, ...$this->expand($event, $from, $to));
        }

        return $items;
    }

    /**
     * @return list<CalendarItem>
     */
    public function expand(CalendarEvent $event, CarbonImmutable $from, CarbonImmutable $to): array
    {
        // All-day end dates are exclusive; timed ones are the last day the event is on.
        $last = $event->all_day ? $event->end_date->subDay() : $event->end_date;
        $first = $event->start_date;
        $multiDay = $last->gt($first);
        $items = [];

        for ($day = $first->max($from); $day->lte($last) && $day->lte($to); $day = $day->addDay()) {
            $isFirst = $day->eq($first);
            $isLast = $day->eq($last);
            $timed = ! $event->all_day && $isFirst;

            $items[] = new CalendarItem(
                source: self::SOURCE,
                id: $multiDay ? $event->id.':'.$day->toDateString() : $event->id,
                title: $event->title,
                date: $day,
                time: $timed ? $event->starts_at?->format('H:i') : null,
                endTime: ! $event->all_day && $isFirst && ! $multiDay ? $event->ends_at?->format('H:i') : null,
                subtitle: $this->subtitle($event, $isFirst, $isLast, $multiDay),
                color: $event->calendar->color,
                meta: [
                    'event_id' => $event->id,
                    'calendar' => $event->calendar->name,
                    'calendar_id' => $event->calendar_id,
                    'account' => $event->calendar->account->email,
                    'location' => $event->location,
                    'description' => $event->description,
                    'html_link' => $event->html_link,
                    'meet_link' => $event->meet_link,
                    'starts_at' => $event->starts_at?->toIso8601String(),
                    'ends_at' => $event->ends_at?->toIso8601String(),
                    'start_date' => $event->start_date->toDateString(),
                    'last_date' => $last->toDateString(),
                    'all_day' => $event->all_day,
                ],
            );
        }

        return $items;
    }

    private function subtitle(CalendarEvent $event, bool $isFirst, bool $isLast, bool $multiDay): ?string
    {
        if (! $multiDay) {
            return $event->location;
        }

        if (! $event->all_day && $isLast && ! $isFirst) {
            return 'Hasta las '.$event->ends_at?->format('H:i');
        }

        return $isFirst ? $event->location : 'Continúa';
    }
}
