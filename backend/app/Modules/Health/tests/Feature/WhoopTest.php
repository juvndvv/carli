<?php

use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Models\WhoopAccount;
use App\Modules\Health\Models\WhoopCycle;
use App\Modules\Health\Models\WhoopRecovery;
use App\Modules\Health\Models\WhoopSleep;
use App\Modules\Health\Models\WhoopWorkout;
use App\Modules\Health\Notifications\WhoopReconnect;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;

require_once __DIR__.'/../Support/WhoopFakes.php';

beforeEach(function () {
    $this->travelTo(HabitCalendar::date('2026-11-04')->setTime(10, 0));
    config([
        'services.whoop.client_id' => 'whoop-client',
        'services.whoop.client_secret' => 'whoop-secret',
        'services.whoop.redirect_url' => 'https://carli.jotade.io/api/v1/health/whoop/callback',
    ]);
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
    $GLOBALS['carli_whoop_faked'] = false;
});

describe('connecting', function () {
    it('builds the consent url with the read scopes and offline access', function () {
        $url = $this->postJson('/api/v1/health/whoop')->assertOk()->json('data.auth_url');
        parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

        expect($url)->toStartWith('https://api.prod.whoop.com/oauth/oauth2/auth?')
            ->and(explode(' ', $query['scope']))->toContain('offline', 'read:cycles', 'read:recovery', 'read:sleep', 'read:workout')
            ->and($query['redirect_uri'])->toBe('https://carli.jotade.io/api/v1/health/whoop/callback')
            ->and(strlen($query['state']))->toBeGreaterThanOrEqual(8);
    });

    it('says when the server has no WHOOP credentials', function () {
        config(['services.whoop.client_id' => null]);

        $this->postJson('/api/v1/health/whoop')->assertStatus(503);
        $this->getJson('/api/v1/health/whoop')->assertOk()->assertJsonPath('data.configured', false)->assertJsonPath('data.account', null);
    });

    it('stores the member with encrypted tokens and copies the last days right away', function () {
        fakeWhoop();

        $account = connectWhoop($this);

        expect($account->whoop_user_id)->toBe(WHOOP_MEMBER)
            ->and($account->email)->toBe('juanda@jotade.io')
            ->and($account->refresh_token)->toBe('refresh-1')
            ->and($account->getRawOriginal('refresh_token'))->not->toBe('refresh-1')
            ->and($account->synced_at)->not->toBeNull()
            ->and(WhoopCycle::query()->count())->toBe(2)
            ->and(WhoopSleep::query()->count())->toBe(2)
            ->and(WhoopRecovery::query()->count())->toBe(1)
            ->and(WhoopWorkout::query()->count())->toBe(1);

        $this->getJson('/api/v1/health/whoop')
            ->assertOk()
            ->assertJsonPath('data.configured', true)
            ->assertJsonPath('data.account.email', 'juanda@jotade.io')
            ->assertJsonPath('data.account.status', 'active');
        Http::assertSent(fn (Request $request) => str_contains($request->url(), '/developer/v2/cycle?') && str_contains($request->url(), 'start=2026-08-06'));
    });

    it('rejects a reused or forged state', function () {
        fakeWhoop();
        connectWhoop($this);

        $this->get('/api/v1/health/whoop/callback?state=forged-state&code=code-2')->assertRedirect('carli://health/whoop?error=estado');
    });

    it('reports a cancelled consent', function () {
        $this->get('/api/v1/health/whoop/callback?error=access_denied&state=x')->assertRedirect('carli://health/whoop?error=cancelado');

        expect(WhoopAccount::query()->count())->toBe(0);
    });
});

describe('days', function () {
    it('groups recovery, night, naps, strain, steps and workouts by day', function () {
        fakeWhoop();
        connectWhoop($this);

        $days = $this->getJson('/api/v1/health/whoop/days?from=2026-11-01&to=2026-11-04')->assertOk()->json('data');

        expect(array_column($days, 'date'))->toBe(['2026-11-04', '2026-11-03'])
            ->and($days[0]['recovery'])->toMatchArray(['score' => 74, 'resting_heart_rate' => 52, 'hrv_ms' => 61.234, 'spo2' => 96.4, 'skin_temp_c' => 33.7, 'calibrating' => false])
            ->and($days[0]['sleep'])->toMatchArray(['asleep_minutes' => 420, 'in_bed_minutes' => 450, 'deep_minutes' => 90, 'rem_minutes' => 120, 'need_minutes' => 482, 'performance' => 92, 'respiratory_rate' => 15.3])
            ->and($days[0]['nap_minutes'])->toBe(30)
            ->and($days[0]['strain'])->toMatchArray(['strain' => 8.4, 'kcal' => 1981, 'steps' => 6214, 'in_progress' => true])
            ->and($days[0]['workouts'])->toHaveCount(1)
            ->and($days[0]['workouts'][0])->toMatchArray(['sport' => 'running', 'strain' => 11.2, 'kcal' => 455, 'distance_m' => 7210.5, 'zone_minutes' => [0, 2, 10, 20, 12, 1]])
            ->and($days[1]['strain'])->toMatchArray(['strain' => 12.6, 'steps' => null, 'in_progress' => false])
            ->and($days[1]['recovery'])->toBeNull();
    });

    it('defaults to the last two weeks and refuses more than a year', function () {
        fakeWhoop();
        connectWhoop($this);

        $this->getJson('/api/v1/health/whoop/days')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/health/whoop/days?from=2025-01-01&to=2026-11-04')->assertStatus(422);
    });

    it('hides other users\' data', function () {
        fakeWhoop();
        connectWhoop($this);

        $this->actingAs(User::factory()->create());

        $this->getJson('/api/v1/health/whoop/days?from=2026-11-01&to=2026-11-04')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/health/whoop')->assertJsonPath('data.account', null);
        $this->postJson('/api/v1/health/whoop/sync')->assertNotFound();
        $this->deleteJson('/api/v1/health/whoop')->assertNotFound();
    });
});

describe('syncing', function () {
    it('drops records deleted in WHOOP and stores the rotated refresh token', function () {
        fakeWhoop();
        $account = connectWhoop($this);

        $this->travel(2)->hours();
        $records = whoopRecords();
        $records['workout'] = [];
        fakeWhoop($records, ['access_token' => 'access-2', 'refresh_token' => 'refresh-2']);

        $this->artisan('health:whoop-sync')->expectsOutputToContain('sincronizadas: 1')->assertSuccessful();

        expect(WhoopWorkout::query()->count())->toBe(0)
            ->and($account->refresh()->access_token)->toBe('access-2')
            ->and($account->refresh_token)->toBe('refresh-2');
        Http::assertSent(fn (Request $request) => str_ends_with($request->url(), '/oauth/oauth2/token')
            && $request['grant_type'] === 'refresh_token' && $request['refresh_token'] === 'refresh-1' && $request['scope'] === 'offline');
    });

    it('flags the account and notifies once when WHOOP revokes the grant', function () {
        Notification::fake();
        fakeWhoop();
        $account = connectWhoop($this);
        $this->travel(2)->hours();

        fakeWhoop(mode: 'revoked');
        $this->artisan('health:whoop-sync')->assertSuccessful();
        // Flagged accounts are skipped, so a second run cannot notify again.
        $this->artisan('health:whoop-sync')->assertSuccessful();
        $this->postJson('/api/v1/health/whoop/sync')->assertStatus(409);

        expect($account->refresh()->status)->toBe(WhoopAccount::RECONNECT);
        Notification::assertSentToTimes($this->user, WhoopReconnect::class, 1);
    });

    it('keeps the data when WHOOP is down', function () {
        fakeWhoop();
        $account = connectWhoop($this);
        $this->travel(2)->hours();
        fakeWhoop(mode: 'down');

        $this->artisan('health:whoop-sync')->expectsOutputToContain('con error: 1');

        expect(WhoopSleep::query()->count())->toBe(2)
            ->and($account->refresh()->status)->toBe(WhoopAccount::ACTIVE)
            ->and($account->last_error)->not->toBeNull();
    });

    it('revokes access on disconnect and keeps what was copied', function () {
        fakeWhoop();
        connectWhoop($this);

        $this->deleteJson('/api/v1/health/whoop')->assertNoContent();

        expect(WhoopAccount::query()->count())->toBe(0)->and(WhoopSleep::query()->count())->toBe(2);
        Http::assertSent(fn (Request $request) => $request->method() === 'DELETE' && str_ends_with($request->url(), '/developer/v2/user/access'));
    });

    it('syncs every hour', function () {
        $event = collect(app(Schedule::class)->events())->first(fn ($event) => str_contains((string) $event->command, 'health:whoop-sync'));

        expect($event?->expression)->toBe('0 * * * *');
    });
});

describe('webhooks', function () {
    it('refuses a bad signature', function () {
        fakeWhoop();
        connectWhoop($this);

        whoopWebhook($this, ['id' => WHOOP_SLEEP, 'type' => 'sleep.deleted'], 'wrong-secret')->assertStatus(401);

        expect(WhoopSleep::query()->count())->toBe(2);
    });

    it('deletes and fetches records as WHOOP reports them', function () {
        fakeWhoop();
        connectWhoop($this);

        whoopWebhook($this, ['id' => WHOOP_WORKOUT, 'type' => 'workout.deleted'])->assertNoContent();
        expect(WhoopWorkout::query()->count())->toBe(0);

        whoopWebhook($this, ['id' => WHOOP_WORKOUT, 'type' => 'workout.updated'])->assertNoContent();
        expect(WhoopWorkout::query()->count())->toBe(1);

        $records = whoopRecords();
        $records['recovery'][0]['score']['recovery_score'] = 81;
        fakeWhoop($records);
        whoopWebhook($this, ['id' => WHOOP_SLEEP, 'type' => 'recovery.updated'])->assertNoContent();
        expect(WhoopRecovery::query()->sole()->recovery_score)->toBe(81);

        whoopWebhook($this, ['id' => WHOOP_SLEEP, 'type' => 'recovery.deleted'])->assertNoContent();
        expect(WhoopRecovery::query()->count())->toBe(0);
    });

    it('acknowledges events for unknown members and types without doing anything', function () {
        fakeWhoop();
        connectWhoop($this);

        whoopWebhook($this, ['id' => WHOOP_SLEEP, 'type' => 'sleep.deleted', 'user_id' => 1])->assertNoContent();
        whoopWebhook($this, ['id' => WHOOP_SLEEP, 'type' => 'body.updated'])->assertNoContent();

        expect(WhoopSleep::query()->count())->toBe(2);
    });
});
