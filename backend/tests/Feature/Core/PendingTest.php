<?php

use App\Core\Notifications\CoreNotificationTypes;
use App\Core\Pending\PendingDigestNotification;
use App\Core\Pending\PendingRegistry;
use App\Models\User;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Notification;
use NotificationChannels\WebPush\WebPushChannel;
use Tests\Feature\Core\Fixtures\Journal\JournalModule;
use Tests\Feature\Core\Fixtures\Journal\JournalPendingItems;

beforeEach(function () {
    JournalModule::register($this->app);
    $this->journal = new JournalPendingItems;
    app(PendingRegistry::class)->register($this->journal);
    $this->user = User::factory()->create();
});

describe('summary', function () {
    it('totals the counts of every enabled module by type', function () {
        $this->actingAs($this->user)->getJson('/api/v1/pending/summary')
            ->assertOk()
            ->assertExactJson(['data' => [
                'total' => 4,
                'by_module' => [
                    ['module' => 'journal', 'module_name' => 'Diario', 'type' => 'entry_to_review', 'count' => 3],
                    ['module' => 'journal', 'module_name' => 'Diario', 'type' => 'draft', 'count' => 1],
                ],
            ]]);
    });

    it('leaves out empty types and disabled modules', function () {
        $this->journal->counts = ['entry_to_review' => 0, 'draft' => 2];

        $this->actingAs($this->user)->getJson('/api/v1/pending/summary')
            ->assertJsonPath('data.total', 2)
            ->assertJsonCount(1, 'data.by_module');

        $this->user->moduleSettings()->create(['module_id' => 'journal', 'enabled' => false]);

        $this->actingAs($this->user)->getJson('/api/v1/pending/summary')
            ->assertExactJson(['data' => ['total' => 0, 'by_module' => []]]);
    });

    it('requires authentication', function () {
        $this->getJson('/api/v1/pending/summary')->assertUnauthorized();
        $this->getJson('/api/v1/pending')->assertUnauthorized();
    });
});

describe('list', function () {
    it('pages through every type with an opaque cursor', function () {
        $first = $this->actingAs($this->user)->getJson('/api/v1/pending')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0', [
                'module' => 'journal',
                'type' => 'entry_to_review',
                'id' => 'entry_to_review-0',
                'title' => 'Entrada 0',
                'subtitle' => null,
                'amount_cents' => null,
                'date' => '2026-10-25',
                'route' => '/diario/0',
                'meta' => [],
            ])
            ->assertJsonPath('meta.has_more', true);

        $ids = collect($first->json('data'))->pluck('id')->all();
        $cursor = $first->json('meta.next_cursor');

        while ($cursor !== null) {
            $page = $this->getJson('/api/v1/pending?cursor='.$cursor)->assertOk();
            $ids = [...$ids, ...collect($page->json('data'))->pluck('id')->all()];
            $cursor = $page->json('meta.next_cursor');
        }

        expect($ids)->toBe(['entry_to_review-0', 'entry_to_review-1', 'entry_to_review-2', 'draft-0']);
    });

    it('filters by module and type', function () {
        $this->actingAs($this->user)->getJson('/api/v1/pending?module=journal&type=draft')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', 'draft-0')
            ->assertJsonPath('meta.next_cursor', null);

        $this->getJson('/api/v1/pending?module=finance')->assertExactJson(['data' => [], 'meta' => ['has_more' => false, 'next_cursor' => null]]);
        $this->getJson('/api/v1/pending?type=unknown')->assertJsonCount(0, 'data');
    });

    it('returns nothing for a malformed cursor or a disabled module', function () {
        $this->actingAs($this->user)->getJson('/api/v1/pending?cursor=nope')->assertJsonCount(0, 'data');

        $this->user->moduleSettings()->create(['module_id' => 'journal', 'enabled' => false]);

        $this->getJson('/api/v1/pending')->assertJsonCount(0, 'data');
    });
});

describe('daily digest', function () {
    beforeEach(fn () => config(['webpush.vapid.public_key' => 'BPublicKeyForTests', 'webpush.vapid.private_key' => 'PrivateKeyForTests']));

    it('sends one summary per user with pending items', function () {
        Notification::fake();
        $idle = User::factory()->create();
        $idle->moduleSettings()->create(['module_id' => 'journal', 'enabled' => false]);

        $this->artisan('core:pending-digest', ['--date' => '2026-10-25'])
            ->expectsOutputToContain('Notificaciones enviadas: 1')
            ->assertSuccessful();

        Notification::assertSentTo($this->user, PendingDigestNotification::class, function (PendingDigestNotification $notification, array $channels) {
            return $notification->body() === 'Tienes 3 entradas por revisar y 1 borrador sin terminar'
                && $notification->toArray($this->user)['url'] === '/pendientes'
                && $channels === ['database', WebPushChannel::class];
        });
        Notification::assertNotSentTo($idle, PendingDigestNotification::class);
    });

    it('never sends twice on the same day', function () {
        Notification::fake();

        $this->artisan('core:pending-digest', ['--date' => '2026-10-25'])->assertSuccessful();
        $this->artisan('core:pending-digest', ['--date' => '2026-10-25'])->expectsOutputToContain('Notificaciones enviadas: 0');
        $this->artisan('core:pending-digest', ['--date' => '2026-10-26'])->expectsOutputToContain('Notificaciones enviadas: 1');

        Notification::assertSentToTimes($this->user, PendingDigestNotification::class, 2);
    });

    it('stays quiet when there is nothing pending', function () {
        Notification::fake();
        $this->journal->counts = ['entry_to_review' => 0];

        $this->artisan('core:pending-digest')->expectsOutputToContain('Notificaciones enviadas: 0');

        Notification::assertNothingSent();
    });

    it('honours the notification preferences', function () {
        $this->user->notificationPreferences()->create(['module_id' => 'core', 'type' => 'pending_digest', 'push' => false, 'in_app' => false]);

        $this->artisan('core:pending-digest')->assertSuccessful();

        expect($this->user->notifications()->count())->toBe(0);
    });

    it('stores the summary in the inbox', function () {
        config(['webpush.vapid.public_key' => null, 'webpush.vapid.private_key' => null]);
        $this->journal->counts = ['entry_to_review' => 7];

        $this->artisan('core:pending-digest')->assertSuccessful();

        expect($this->user->notifications()->first()?->data)->toMatchArray([
            'module' => 'core',
            'type' => 'pending_digest',
            'title' => 'Pendientes por revisar',
            'body' => 'Tienes 7 entradas por revisar',
            'url' => '/pendientes',
        ]);
    });

    it('is scheduled daily at 20:00 in Madrid', function () {
        $event = collect(app(Schedule::class)->events())
            ->first(fn ($event) => str_contains((string) $event->command, 'core:pending-digest'));

        expect($event)->not->toBeNull()
            ->and($event->expression)->toBe('0 20 * * *')
            ->and($event->timezone)->toBe('Europe/Madrid');
    });
});

describe('notification preferences', function () {
    it('lists the digest as a general type, on by default', function () {
        $this->actingAs($this->user)->getJson('/api/v1/notification-preferences')
            ->assertOk()
            ->assertJsonPath('data.0.module', CoreNotificationTypes::MODULE)
            ->assertJsonPath('data.0.name', 'General')
            ->assertJsonPath('data.0.types.0.type', 'pending_digest')
            ->assertJsonPath('data.0.types.0.push', true)
            ->assertJsonPath('data.0.types.0.in_app', true)
            ->assertJsonPath('data.1.module', 'journal');
    });

    it('accepts updates to the digest preference', function () {
        $this->actingAs($this->user)->putJson('/api/v1/notification-preferences', [
            'preferences' => [['module' => 'core', 'type' => 'pending_digest', 'push' => false, 'in_app' => true]],
        ])->assertOk()->assertJsonPath('data.0.types.0.push', false);

        $this->putJson('/api/v1/notification-preferences', [
            'preferences' => [['module' => 'core', 'type' => 'nope', 'push' => false, 'in_app' => true]],
        ])->assertUnprocessable();
    });

    it('hides the general group when no enabled module contributes pending items', function () {
        $this->user->moduleSettings()->create(['module_id' => 'journal', 'enabled' => false]);

        $this->actingAs($this->user)->getJson('/api/v1/notification-preferences')
            ->assertJsonPath('data.0.module', 'journal');
    });
});
