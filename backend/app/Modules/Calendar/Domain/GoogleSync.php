<?php

namespace App\Modules\Calendar\Domain;

use App\Modules\Calendar\Google\GoogleAccessRevoked;
use App\Modules\Calendar\Google\GoogleClient;
use App\Modules\Calendar\Google\GoogleException;
use App\Modules\Calendar\Google\GoogleTokenRejected;
use App\Modules\Calendar\Models\CalendarEvent;
use App\Modules\Calendar\Models\GoogleAccount;
use App\Modules\Calendar\Models\GoogleCalendar;
use App\Modules\Calendar\Notifications\GoogleReconnect;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Copies a linked account's calendars and the event instances of the selected ones inside a moving window
 * (CalendarClock::PAST_DAYS back, FUTURE_DAYS ahead). Each run replaces the window, so edits and
 * deletions in Google show up on the next run without sync tokens.
 */
final readonly class GoogleSync
{
    private const int DESCRIPTION_LIMIT = 4000;

    /** @var list<string> */
    private const array SKIPPED_TYPES = ['workingLocation'];

    public function __construct(private GoogleClient $google) {}

    /**
     * Syncs an account and records the outcome on it; a revoked grant flags the account and notifies once.
     */
    public function run(GoogleAccount $account): bool
    {
        try {
            $this->account($account);

            return true;
        } catch (GoogleAccessRevoked $exception) {
            $wasActive = ! $account->needsReconnect();
            $account->forceFill(['status' => GoogleAccount::RECONNECT, 'last_error' => $exception->getMessage()])->save();

            if ($wasActive) {
                $account->user->notify(new GoogleReconnect($account->email));
            }

            return false;
        } catch (GoogleException $exception) {
            $account->forceFill(['last_error' => mb_substr($exception->getMessage(), 0, 500)])->save();

            return false;
        }
    }

    /**
     * @param  list<array<string, mixed>>|null  $calendarList  Already fetched by the caller (the OAuth callback)
     */
    public function account(GoogleAccount $account, ?array $calendarList = null): void
    {
        $calendarList ??= $this->withToken($account, fn (string $token) => $this->google->calendars($token));
        $this->storeCalendars($account, $calendarList);

        $today = CalendarClock::today();
        $from = $today->subDays(CalendarClock::PAST_DAYS);
        $to = $today->addDays(CalendarClock::FUTURE_DAYS);

        foreach ($account->calendars()->get() as $calendar) {
            if (! $calendar->selected) {
                $calendar->events()->delete();

                continue;
            }

            $events = $this->withToken($account, fn (string $token) => $this->google->events($token, $calendar->google_id, $from, $to));
            $this->storeEvents($calendar, $events);
        }

        $account->forceFill(['synced_at' => CarbonImmutable::now(), 'last_error' => null, 'status' => GoogleAccount::ACTIVE])->save();
    }

    /**
     * Copies one calendar again (after it is switched on), keeping the account's token fresh.
     */
    public function calendar(GoogleCalendar $calendar): void
    {
        if (! $calendar->selected) {
            $calendar->events()->delete();

            return;
        }

        $today = CalendarClock::today();
        $events = $this->withToken($calendar->account, fn (string $token) => $this->google->events(
            $token, $calendar->google_id, $today->subDays(CalendarClock::PAST_DAYS), $today->addDays(CalendarClock::FUTURE_DAYS),
        ));
        $this->storeEvents($calendar, $events);
    }

    /**
     * @template T
     *
     * @param  callable(string): T  $call
     * @return T
     */
    private function withToken(GoogleAccount $account, callable $call): mixed
    {
        if ($account->access_token === null || $account->token_expires_at === null || $account->token_expires_at->isPast()) {
            $this->refreshToken($account);
        }

        try {
            return $call((string) $account->access_token);
        } catch (GoogleTokenRejected) {
            $this->refreshToken($account);

            return $call((string) $account->access_token);
        }
    }

    private function refreshToken(GoogleAccount $account): void
    {
        $tokens = $this->google->refresh($account->refresh_token);

        $account->forceFill([
            'access_token' => $tokens['access_token'],
            'token_expires_at' => $tokens['expires_at'],
            'refresh_token' => $tokens['refresh_token'] ?? $account->refresh_token,
        ])->save();
    }

    /**
     * @param  list<array<string, mixed>>  $items
     */
    private function storeCalendars(GoogleAccount $account, array $items): void
    {
        $seen = [];

        foreach ($items as $index => $item) {
            $googleId = $item['id'] ?? null;

            if (! is_string($googleId) || $googleId === '') {
                continue;
            }

            $seen[] = $googleId;
            $calendar = GoogleCalendar::query()->firstOrNew(['account_id' => $account->id, 'google_id' => $googleId]);
            $isNew = ! $calendar->exists;

            $calendar->fill([
                'user_id' => $account->user_id,
                'name' => (string) ($item['summaryOverride'] ?? $item['summary'] ?? $googleId),
                'color' => is_string($item['backgroundColor'] ?? null) ? $item['backgroundColor'] : null,
                'primary' => ($item['primary'] ?? false) === true,
                'sort' => $index,
            ]);

            if ($isNew) {
                // Start with what the account shows in Google Calendar itself.
                $calendar->selected = ($item['primary'] ?? false) === true || ($item['selected'] ?? false) === true;
            }

            $calendar->save();
        }

        GoogleCalendar::query()->where('account_id', $account->id)->whereNotIn('google_id', $seen)->delete();
        $account->unsetRelation('calendars');
    }

    /**
     * @param  list<array<string, mixed>>  $items
     */
    private function storeEvents(GoogleCalendar $calendar, array $items): void
    {
        $rows = [];

        foreach ($items as $item) {
            $row = $this->eventRow($item);

            if ($row !== null) {
                $rows[$row['google_id']] = $row;
            }
        }

        DB::transaction(function () use ($calendar, $rows): void {
            CalendarEvent::query()->where('calendar_id', $calendar->id)->whereNotIn('google_id', array_keys($rows) ?: [''])->delete();

            foreach ($rows as $googleId => $row) {
                CalendarEvent::query()->updateOrCreate(
                    ['calendar_id' => $calendar->id, 'google_id' => $googleId],
                    $row + ['user_id' => $calendar->user_id],
                );
            }
        });
    }

    /**
     * @param  array<string, mixed>  $item
     * @return array<string, mixed>|null
     */
    private function eventRow(array $item): ?array
    {
        $googleId = $item['id'] ?? null;

        if (! is_string($googleId) || ($item['status'] ?? null) === 'cancelled' || $this->declined($item)) {
            return null;
        }

        // Working location ("Oficina", "Casa") is a status in Google, not something on the agenda.
        if (in_array($item['eventType'] ?? null, self::SKIPPED_TYPES, true)) {
            return null;
        }

        $start = is_array($item['start'] ?? null) ? $item['start'] : [];
        $end = is_array($item['end'] ?? null) ? $item['end'] : [];
        $row = [
            'google_id' => $googleId,
            'title' => trim((string) ($item['summary'] ?? '')) ?: '(Sin título)',
            'location' => is_string($item['location'] ?? null) ? mb_substr($item['location'], 0, 500) : null,
            'description' => is_string($item['description'] ?? null) ? mb_substr($item['description'], 0, self::DESCRIPTION_LIMIT) : null,
            'html_link' => is_string($item['htmlLink'] ?? null) ? $item['htmlLink'] : null,
            'meet_link' => is_string($item['hangoutLink'] ?? null) ? $item['hangoutLink'] : null,
        ];

        if (is_string($start['date'] ?? null)) {
            $startDate = CalendarClock::date($start['date']);
            $endDate = is_string($end['date'] ?? null) ? CalendarClock::date($end['date']) : $startDate->addDay();

            return $row + [
                'all_day' => true,
                'starts_at' => null,
                'ends_at' => null,
                'start_date' => $startDate->toDateString(),
                'end_date' => $endDate->max($startDate->addDay())->toDateString(),
            ];
        }

        if (! is_string($start['dateTime'] ?? null)) {
            return null;
        }

        $startsAt = CarbonImmutable::parse($start['dateTime'])->setTimezone(CalendarClock::TIMEZONE);
        $endsAt = is_string($end['dateTime'] ?? null) ? CarbonImmutable::parse($end['dateTime'])->setTimezone(CalendarClock::TIMEZONE) : $startsAt;
        $endsAt = $endsAt->max($startsAt);
        // The last day the event is on: one ending at 00:00 belongs to the day before.
        $lastDay = $endsAt->gt($startsAt) ? $endsAt->subSecond()->startOfDay() : $startsAt->startOfDay();

        return $row + [
            'all_day' => false,
            'starts_at' => $startsAt,
            'ends_at' => $endsAt,
            'start_date' => $startsAt->toDateString(),
            'end_date' => $lastDay->toDateString(),
        ];
    }

    /**
     * @param  array<string, mixed>  $item
     */
    private function declined(array $item): bool
    {
        foreach ((array) ($item['attendees'] ?? []) as $attendee) {
            if (is_array($attendee) && ($attendee['self'] ?? false) === true) {
                return ($attendee['responseStatus'] ?? null) === 'declined';
            }
        }

        return false;
    }
}
