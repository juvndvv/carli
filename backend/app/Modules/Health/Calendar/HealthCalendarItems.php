<?php

namespace App\Modules\Health\Calendar;

use App\Core\Calendar\CalendarItem;
use App\Core\Calendar\CalendarItemsProvider;
use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Domain\HealthSettings;
use App\Modules\Health\Models\BodyMeasurement;
use App\Modules\Health\Models\Measurement;
use Carbon\CarbonImmutable;

/**
 * Weigh-ins and tape measurements done, plus the reminder days still to come (or missed).
 */
final readonly class HealthCalendarItems implements CalendarItemsProvider
{
    public const string SOURCE = 'health';

    public function __construct(private HealthSettings $settings) {}

    public function moduleId(): string
    {
        return HealthSettings::MODULE;
    }

    public function items(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $start = HabitCalendar::date($from);
        $end = HabitCalendar::date($to)->addDay();
        $config = $this->settings->for($user);
        $today = HabitCalendar::today();
        $items = [];

        /** @var array<string, Measurement> $weighIns first weigh-in of each day */
        $weighIns = [];
        foreach (Measurement::query()->ownedBy($user)->where('measured_at', '>=', $start)->where('measured_at', '<', $end)->orderBy('measured_at')->get() as $measurement) {
            $weighIns[$measurement->measured_at->setTimezone(HabitCalendar::TIMEZONE)->toDateString()] ??= $measurement;
        }

        /** @var array<string, CarbonImmutable> $bodyDays */
        $bodyDays = [];
        foreach (BodyMeasurement::query()->ownedBy($user)->where('measured_at', '>=', $start)->where('measured_at', '<', $end)->orderBy('measured_at')->pluck('measured_at') as $measuredAt) {
            $local = CarbonImmutable::parse($measuredAt)->setTimezone(HabitCalendar::TIMEZONE);
            $bodyDays[$local->toDateString()] ??= $local;
        }

        for ($day = $start; $day->lt($end); $day = $day->addDay()) {
            $key = $day->toDateString();
            $reminderDay = $config['reminder_enabled'] && in_array($day->dayOfWeekIso, $config['reminder_days'], true);

            if (isset($weighIns[$key])) {
                $weighIn = $weighIns[$key];
                $items[] = new CalendarItem(
                    source: self::SOURCE,
                    id: 'weight:'.$key,
                    title: 'Pesada',
                    date: $day,
                    time: $weighIn->measured_at->setTimezone(HabitCalendar::TIMEZONE)->format('H:i'),
                    done: true,
                    subtitle: number_format($weighIn->weight(), 1, ',', '.').' kg',
                    url: '/salud/mediciones/'.$weighIn->id,
                    meta: ['measurement_id' => $weighIn->id, 'weight_kg' => $weighIn->weight()],
                );
            } elseif ($reminderDay && $config['reminder_weight'] && $day->gte($today)) {
                $items[] = $this->reminder('weight:'.$key, 'Pesarse', $day, $config['reminder_time'], '/salud/pesarse');
            }

            if (isset($bodyDays[$key])) {
                $items[] = new CalendarItem(
                    source: self::SOURCE,
                    id: 'body:'.$key,
                    title: 'Medidas del cuerpo',
                    date: $day,
                    time: $bodyDays[$key]->format('H:i'),
                    done: true,
                    url: '/salud/cuerpo',
                );
            } elseif ($reminderDay && $config['reminder_body'] && $day->gte($today)) {
                $items[] = $this->reminder('body:'.$key, 'Medirse', $day, $config['reminder_time'], '/salud/medirse');
            }
        }

        return $items;
    }

    private function reminder(string $id, string $title, CarbonImmutable $day, string $time, string $url): CalendarItem
    {
        return new CalendarItem(
            source: self::SOURCE,
            id: $id,
            title: $title,
            date: $day,
            time: substr($time, 0, 5),
            subtitle: 'Recordatorio',
            url: $url,
            meta: ['reminder' => true],
        );
    }
}
