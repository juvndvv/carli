<?php

namespace App\Core\Calendar;

use Carbon\CarbonImmutable;

/**
 * One dated thing shown in the unified calendar, whatever module or Google calendar it comes from.
 * Items with no time are all-day; `ends` only matters for timed or multi-day events.
 */
final readonly class CalendarItem
{
    /**
     * @param  string  $source  Filter group the app toggles: google, tasks, templates, finance, health, habits
     * @param  array<string, mixed>  $meta
     */
    public function __construct(
        public string $source,
        public string $id,
        public string $title,
        public CarbonImmutable $date,
        public ?string $time = null,
        public ?CarbonImmutable $endDate = null,
        public ?string $endTime = null,
        public bool $done = false,
        public ?string $subtitle = null,
        public ?string $color = null,
        public ?string $url = null,
        public array $meta = [],
    ) {}

    public function allDay(): bool
    {
        return $this->time === null;
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'source' => $this->source,
            'id' => $this->id,
            'title' => $this->title,
            'date' => $this->date->toDateString(),
            'time' => $this->time,
            'end_date' => $this->endDate?->toDateString(),
            'end_time' => $this->endTime,
            'all_day' => $this->allDay(),
            'done' => $this->done,
            'subtitle' => $this->subtitle,
            'color' => $this->color,
            'url' => $this->url,
            'meta' => (object) $this->meta,
        ];
    }
}
