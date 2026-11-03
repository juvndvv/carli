<?php

namespace App\Core\Calendar;

use App\Models\User;
use Carbon\CarbonImmutable;

/**
 * A module's contribution to the unified calendar. Dates are Europe/Madrid calendar days, both ends included.
 */
interface CalendarItemsProvider
{
    public function moduleId(): string;

    /**
     * @return list<CalendarItem>
     */
    public function items(User $user, CarbonImmutable $from, CarbonImmutable $to): array;
}
