<?php

namespace App\Modules\Calendar\Digest;

use App\Core\Pending\DigestLineProvider;
use App\Models\User;
use App\Modules\Calendar\CalendarServiceProvider;
use App\Modules\Calendar\Domain\CalendarClock;
use App\Modules\Calendar\Items\GoogleEventItems;

/**
 * The 20:00 digest line about tomorrow's Google events.
 */
final readonly class CalendarDigestProvider implements DigestLineProvider
{
    public function __construct(private GoogleEventItems $events) {}

    public function moduleId(): string
    {
        return CalendarServiceProvider::MODULE;
    }

    public function digestLines(User $user): array
    {
        $tomorrow = CalendarClock::today()->addDay();
        $items = $this->events->items($user, $tomorrow, $tomorrow);

        if ($items === []) {
            return [];
        }

        $timed = array_values(array_filter($items, fn ($item) => $item->time !== null));
        usort($timed, fn ($left, $right) => $left->time <=> $right->time);
        $count = count($items);
        $line = $count === 1 ? 'Mañana tienes 1 evento' : "Mañana tienes {$count} eventos";

        if ($timed !== []) {
            $line .= sprintf(', el primero a las %s (%s)', $timed[0]->time, $timed[0]->title);
        } elseif ($count === 1) {
            $line .= ': '.$items[0]->title;
        }

        return [$line];
    }
}
