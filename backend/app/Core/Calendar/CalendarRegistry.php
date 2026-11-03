<?php

namespace App\Core\Calendar;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Container\Container;

/**
 * Collects the calendar items of every enabled module, the same way PendingRegistry collects pending items.
 */
final class CalendarRegistry
{
    /** @var array<string, class-string<CalendarItemsProvider>|CalendarItemsProvider> */
    private array $registered = [];

    public function __construct(private readonly Container $container) {}

    /**
     * @param  class-string<CalendarItemsProvider>|CalendarItemsProvider  $provider
     */
    public function register(string|CalendarItemsProvider $provider): void
    {
        $this->registered[is_string($provider) ? $provider : $provider::class] = $provider;
    }

    /**
     * Sorted by day, then all-day items first, then by time and title.
     *
     * @return list<CalendarItem>
     */
    public function items(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $modules = $this->container->make(ModuleRegistry::class);
        $items = [];

        foreach ($this->registered as $provider) {
            $instance = is_string($provider) ? $this->container->make($provider) : $provider;

            if ($modules->isEnabledFor($user, $instance->moduleId())) {
                array_push($items, ...$instance->items($user, $from, $to));
            }
        }

        usort($items, fn (CalendarItem $left, CalendarItem $right) => [$left->date->toDateString(), $left->time !== null, $left->time ?? '', mb_strtolower($left->title)]
            <=> [$right->date->toDateString(), $right->time !== null, $right->time ?? '', mb_strtolower($right->title)]);

        return $items;
    }
}
