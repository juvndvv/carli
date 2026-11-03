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

require_once __DIR__.'/../Support/GoogleFakes.php';

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
