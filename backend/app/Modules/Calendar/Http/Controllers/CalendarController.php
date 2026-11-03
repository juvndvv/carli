<?php

namespace App\Modules\Calendar\Http\Controllers;

use App\Core\Calendar\CalendarItem;
use App\Core\Calendar\CalendarRegistry;
use App\Models\User;
use App\Modules\Calendar\Http\Requests\CalendarRangeRequest;
use App\Modules\Calendar\Jobs\SyncGoogleAccountJob;
use App\Modules\Calendar\Models\GoogleAccount;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;

final class CalendarController
{
    /** Opening the calendar refreshes accounts copied longer ago than this. */
    private const int STALE_MINUTES = 5;

    public function __invoke(CalendarRangeRequest $request, CalendarRegistry $calendar): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $accounts = GoogleAccount::query()->ownedBy($user)->get();

        foreach ($accounts as $account) {
            if (! $account->needsReconnect() && ($account->synced_at === null || $account->synced_at->lt(CarbonImmutable::now()->subMinutes(self::STALE_MINUTES)))) {
                SyncGoogleAccountJob::dispatch($account->id);
            }
        }

        return response()->json(['data' => [
            'from' => $request->from()->toDateString(),
            'to' => $request->to()->toDateString(),
            'items' => array_map(fn (CalendarItem $item) => $item->toArray(), $calendar->items($user, $request->from(), $request->to())),
            'google' => [
                'accounts' => $accounts->count(),
                'reconnect' => $accounts->filter->needsReconnect()->pluck('email')->values(),
                'synced_at' => $accounts->max('synced_at')?->toIso8601String(),
            ],
        ]]);
    }
}
