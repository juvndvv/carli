<?php

use App\Models\User;
use App\Modules\Calendar\Domain\CalendarClock;
use App\Modules\Calendar\Models\CalendarEvent;
use App\Modules\Calendar\Models\GoogleAccount;
use App\Modules\Calendar\Models\GoogleCalendar;
use App\Modules\Calendar\Notifications\GoogleReconnect;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;

const GOOGLE_SCOPE = 'https://www.googleapis.com/auth/calendar.readonly';

beforeEach(function () {
    $this->travelTo(CalendarClock::date('2026-11-03')->setTime(10, 0));
    config([
        'services.google.client_id' => 'client-id.apps.googleusercontent.com',
        'services.google.client_secret' => 'secret',
        'services.google.redirect_url' => 'https://carli.jotade.io/api/v1/calendar/google/callback',
    ]);
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
    $GLOBALS['carli_google_faked'] = false;
});

/**
 * @param  array<string, list<array<string, mixed>>>  $events  google calendar id => events
 * @param  array<string, mixed>  $token
 */
function fakeGoogle(array $events = [], array $token = [], ?array $calendars = null, string $mode = 'ok'): void
{
    $calendars ??= [
        ['id' => 'juanda@jotade.io', 'summary' => 'juanda@jotade.io', 'backgroundColor' => '#9fe1e7', 'primary' => true, 'selected' => true, 'accessRole' => 'owner'],
        ['id' => 'family@group.calendar.google.com', 'summary' => 'Familia', 'backgroundColor' => '#f691b2', 'selected' => true, 'accessRole' => 'writer'],
        ['id' => 'es.spain#holiday@group.v.calendar.google.com', 'summary' => 'Festivos en España', 'backgroundColor' => '#16a765', 'accessRole' => 'reader'],
    ];

    // Http::fake() stacks and the first stub wins, so one callback reads whatever the test set last.
    $GLOBALS['carli_google_fake'] = compact('events', 'token', 'calendars', 'mode');

    if ($GLOBALS['carli_google_faked'] ?? false) {
        return;
    }

    $GLOBALS['carli_google_faked'] = true;

    Http::fake(function (Request $request) {
        ['events' => $events, 'token' => $token, 'calendars' => $calendars, 'mode' => $mode] = $GLOBALS['carli_google_fake'];
        $url = $request->url();

        if ($mode === 'down') {
            return Http::response([], 503);
        }

        if (str_starts_with($url, 'https://oauth2.googleapis.com/token')) {
            return $mode === 'revoked'
                ? Http::response(['error' => 'invalid_grant', 'error_description' => 'Token has been expired or revoked.'], 400)
                : Http::response($token + ['access_token' => 'access-1', 'refresh_token' => 'refresh-1', 'expires_in' => 3599, 'scope' => GOOGLE_SCOPE, 'token_type' => 'Bearer']);
        }

        if (str_starts_with($url, 'https://oauth2.googleapis.com/revoke')) {
            return Http::response([]);
        }

        if (str_contains($url, '/users/me/calendarList')) {
            return Http::response(['items' => $calendars]);
        }

        if (preg_match('#/calendars/([^/]+)/events#', $url, $match)) {
            return Http::response(['items' => $events[rawurldecode($match[1])] ?? []]);
        }

        return Http::response(['error' => ['message' => 'unexpected '.$url]], 500);
    });
}

function googleEvents(): array
{
    return [
        'juanda@jotade.io' => [
            ['id' => 'dentist', 'status' => 'confirmed', 'summary' => 'Dentista', 'location' => 'Calle Mayor 3', 'htmlLink' => 'https://calendar.google.com/e/dentist',
                'start' => ['dateTime' => '2026-11-04T09:30:00+01:00'], 'end' => ['dateTime' => '2026-11-04T10:15:00+01:00']],
            ['id' => 'trip', 'status' => 'confirmed', 'summary' => 'Viaje a Lisboa', 'start' => ['date' => '2026-11-06'], 'end' => ['date' => '2026-11-09']],
            ['id' => 'declined', 'status' => 'confirmed', 'summary' => 'Reunión rechazada', 'start' => ['dateTime' => '2026-11-04T12:00:00+01:00'], 'end' => ['dateTime' => '2026-11-04T13:00:00+01:00'],
                'attendees' => [['email' => 'juanda@jotade.io', 'self' => true, 'responseStatus' => 'declined']]],
            ['id' => 'cancelled', 'status' => 'cancelled'],
            ['id' => 'utc', 'status' => 'confirmed', 'summary' => 'Llamada', 'start' => ['dateTime' => '2026-11-05T17:00:00Z'], 'end' => ['dateTime' => '2026-11-05T17:30:00Z']],
        ],
        'family@group.calendar.google.com' => [
            ['id' => 'dinner', 'status' => 'confirmed', 'summary' => 'Cena familiar', 'start' => ['dateTime' => '2026-11-04T21:00:00+01:00'], 'end' => ['dateTime' => '2026-11-05T00:00:00+01:00']],
        ],
    ];
}

function connectGoogle(object $test): GoogleAccount
{
    $url = $test->postJson('/api/v1/calendar/google/accounts')->assertOk()->json('data.auth_url');
    parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

    $test->get('/api/v1/calendar/google/callback?'.http_build_query(['state' => $query['state'], 'code' => 'code-1', 'scope' => GOOGLE_SCOPE]))
        ->assertRedirectContains('carli://calendar/google?account=');

    return GoogleAccount::query()->firstOrFail();
}

describe('connecting', function () {
    it('builds the consent url with the read-only scope and offline access', function () {
        $url = $this->postJson('/api/v1/calendar/google/accounts')->assertOk()->json('data.auth_url');
        parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

        expect($url)->toStartWith('https://accounts.google.com/o/oauth2/v2/auth?')
            ->and($query['scope'])->toBe(GOOGLE_SCOPE)
            ->and($query['access_type'])->toBe('offline')
            ->and($query['redirect_uri'])->toBe('https://carli.jotade.io/api/v1/calendar/google/callback')
            ->and($query['state'])->not->toBeEmpty();
    });

    it('says when the server has no Google credentials', function () {
        config(['services.google.client_id' => null]);

        $this->postJson('/api/v1/calendar/google/accounts')->assertStatus(503);
        $this->getJson('/api/v1/calendar/google/accounts')->assertOk()->assertJsonPath('data.configured', false);
    });

    it('stores the account, its calendars and the events of the visible ones', function () {
        fakeGoogle(googleEvents());

        $account = connectGoogle($this);

        expect($account->email)->toBe('juanda@jotade.io')
            ->and($account->refresh_token)->toBe('refresh-1')
            ->and($account->getRawOriginal('refresh_token'))->not->toBe('refresh-1')
            ->and($account->synced_at)->not->toBeNull();

        $this->getJson('/api/v1/calendar/google/accounts')
            ->assertOk()
            ->assertJsonPath('data.configured', true)
            ->assertJsonPath('data.accounts.0.email', 'juanda@jotade.io')
            ->assertJsonPath('data.accounts.0.calendars.*.name', ['juanda@jotade.io', 'Familia', 'Festivos en España'])
            ->assertJsonPath('data.accounts.0.calendars.*.selected', [true, true, false]);

        expect(CalendarEvent::query()->orderBy('google_id')->pluck('google_id')->all())->toBe(['dentist', 'dinner', 'trip', 'utc']);

        $call = CalendarEvent::query()->where('google_id', 'utc')->firstOrFail();
        expect($call->starts_at?->setTimezone('Europe/Madrid')->format('Y-m-d H:i'))->toBe('2026-11-05 18:00');

        // Ending at midnight keeps the dinner on one day.
        expect(CalendarEvent::query()->where('google_id', 'dinner')->firstOrFail()->end_date->toDateString())->toBe('2026-11-04');

        Http::assertSent(fn (Request $request) => str_contains($request->url(), 'family%40group.calendar.google.com/events')
            && str_contains($request->url(), 'singleEvents=true'));
        Http::assertNotSent(fn (Request $request) => str_contains($request->url(), 'holiday'));
    });

    it('links a second account and updates the first one when linked again', function () {
        fakeGoogle();
        connectGoogle($this);
        fakeGoogle(calendars: [['id' => 'juanda@empresa.com', 'summary' => 'Trabajo', 'primary' => true]]);
        connectGoogle($this);
        connectGoogle($this);

        expect(GoogleAccount::query()->orderBy('email')->pluck('email')->all())->toBe(['juanda@empresa.com', 'juanda@jotade.io']);
    });

    it('rejects a reused or forged state', function () {
        fakeGoogle();
        $url = $this->postJson('/api/v1/calendar/google/accounts')->json('data.auth_url');
        parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

        $this->get('/api/v1/calendar/google/callback?'.http_build_query(['state' => $query['state'], 'code' => 'c']))->assertRedirectContains('account=');
        $this->get('/api/v1/calendar/google/callback?'.http_build_query(['state' => $query['state'], 'code' => 'c']))->assertRedirect('carli://calendar/google?error=estado');
        $this->get('/api/v1/calendar/google/callback?state=nope&code=c')->assertRedirect('carli://calendar/google?error=estado');
    });

    it('reports a cancelled consent and a missing calendar permission', function () {
        fakeGoogle(token: ['scope' => 'openid']);
        $url = $this->postJson('/api/v1/calendar/google/accounts')->json('data.auth_url');
        parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

        $this->get('/api/v1/calendar/google/callback?error=access_denied&state=x')->assertRedirect('carli://calendar/google?error=cancelado');
        $this->get('/api/v1/calendar/google/callback?'.http_build_query(['state' => $query['state'], 'code' => 'c']))->assertRedirect('carli://calendar/google?error=permisos');

        expect(GoogleAccount::query()->count())->toBe(0);
    });
});

describe('syncing', function () {
    it('drops events deleted in Google and refreshes an expired token', function () {
        fakeGoogle(googleEvents());
        $account = connectGoogle($this);

        $this->travel(2)->hours();
        $events = googleEvents();
        array_shift($events['juanda@jotade.io']);
        fakeGoogle($events, ['access_token' => 'access-2', 'refresh_token' => null]);

        $this->artisan('calendar:sync')->expectsOutputToContain('Cuentas sincronizadas: 1')->assertSuccessful();

        expect(CalendarEvent::query()->where('google_id', 'dentist')->exists())->toBeFalse()
            ->and($account->refresh()->access_token)->toBe('access-2')
            ->and($account->refresh_token)->toBe('refresh-1');
        Http::assertSent(fn (Request $request) => $request->url() === 'https://oauth2.googleapis.com/token' && $request['grant_type'] === 'refresh_token');
    });

    it('flags the account and notifies once when Google revokes the grant', function () {
        Notification::fake();
        fakeGoogle(googleEvents());
        $account = connectGoogle($this);
        $this->travel(2)->hours();

        fakeGoogle(mode: 'revoked');
        $this->artisan('calendar:sync')->assertSuccessful();
        // Flagged accounts are skipped, so a second run cannot notify again.
        $this->artisan('calendar:sync')->assertSuccessful();
        $this->postJson("/api/v1/calendar/google/accounts/{$account->id}/sync")->assertStatus(409);

        expect($account->refresh()->status)->toBe(GoogleAccount::RECONNECT);
        Notification::assertSentToTimes($this->user, GoogleReconnect::class, 1);
        $this->getJson('/api/v1/calendar?from=2026-11-01&to=2026-11-07')->assertJsonPath('data.google.reconnect', ['juanda@jotade.io']);
    });

    it('keeps the events when Google is down', function () {
        fakeGoogle(googleEvents());
        $account = connectGoogle($this);
        $this->travel(2)->hours();
        fakeGoogle(mode: 'down');

        $this->artisan('calendar:sync')->expectsOutputToContain('con error: 1');

        expect(CalendarEvent::query()->count())->toBe(4)
            ->and($account->refresh()->status)->toBe(GoogleAccount::ACTIVE)
            ->and($account->last_error)->not->toBeNull();
    });

    it('copies or clears a calendar when it is switched', function () {
        fakeGoogle(googleEvents());
        connectGoogle($this);
        $family = GoogleCalendar::query()->where('name', 'Familia')->firstOrFail();

        $this->patchJson("/api/v1/calendar/google/calendars/{$family->id}", ['selected' => false])->assertOk()->assertJsonPath('data.selected', false);
        expect(CalendarEvent::query()->where('calendar_id', $family->id)->count())->toBe(0);

        $this->patchJson("/api/v1/calendar/google/calendars/{$family->id}", ['selected' => true])->assertOk();
        expect(CalendarEvent::query()->where('calendar_id', $family->id)->count())->toBe(1);
    });

    it('forgets an account and revokes its token', function () {
        fakeGoogle(googleEvents());
        $account = connectGoogle($this);

        $this->deleteJson("/api/v1/calendar/google/accounts/{$account->id}")->assertNoContent();

        expect(GoogleAccount::query()->count())->toBe(0)->and(CalendarEvent::query()->count())->toBe(0);
        Http::assertSent(fn (Request $request) => str_starts_with($request->url(), 'https://oauth2.googleapis.com/revoke'));
    });

    it('hides other users\' accounts and calendars', function () {
        fakeGoogle(googleEvents());
        $account = connectGoogle($this);
        $calendar = GoogleCalendar::query()->firstOrFail();

        $this->actingAs(User::factory()->create());

        $this->deleteJson("/api/v1/calendar/google/accounts/{$account->id}")->assertNotFound();
        $this->patchJson("/api/v1/calendar/google/calendars/{$calendar->id}", ['selected' => false])->assertNotFound();
        $this->getJson('/api/v1/calendar?from=2026-11-01&to=2026-11-30')->assertJsonCount(0, 'data.items');
    });

    it('syncs every 15 minutes', function () {
        $event = collect(app(Schedule::class)->events())->first(fn ($event) => str_contains((string) $event->command, 'calendar:sync'));

        expect($event?->expression)->toBe('*/15 * * * *');
    });
});
