<?php

use App\Core\Notifications\NotificationChannels;
use App\Core\Notifications\TestNotification;
use App\Core\Push\ApnsChannel;
use App\Models\User;
use Illuminate\Support\Facades\Notification;
use Tests\Feature\Core\Fixtures\Journal\JournalModule;
use Tests\Feature\Core\Fixtures\Journal\JournalNotification;

beforeEach(fn () => JournalModule::register($this->app));

function configurePush(bool $configured): void
{
    configureApns($configured);
}

function withDevice(User $user): User
{
    $user->pushDevices()->create(['token' => str_repeat('ab', 32), 'environment' => 'sandbox']);

    return $user;
}

describe('inbox', function () {
    it('lists notifications newest first with the unread count', function () {
        configurePush(false);
        $user = User::factory()->create();

        $user->notify(new JournalNotification);
        $this->travel(1)->minutes();
        $user->notify(new TestNotification);
        $user->notifications()->latest()->first()->markAsRead();

        $this->actingAs($user)->getJson('/api/v1/notifications')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.module', 'core')
            ->assertJsonPath('data.0.type', 'test')
            ->assertJsonPath('data.0.title', 'Notificación de prueba')
            ->assertJsonPath('data.1.module', 'journal')
            ->assertJsonPath('data.1.url', '/diario')
            ->assertJsonPath('data.1.read_at', null)
            ->assertJsonPath('meta.unread_count', 1)
            ->assertJsonPath('meta.total', 2)
            ->assertJsonStructure(['data' => [['id', 'module', 'type', 'title', 'body', 'url', 'read_at', 'created_at']], 'links', 'meta']);
    });

    it('filters unread notifications and paginates', function () {
        configurePush(false);
        $user = User::factory()->create();

        foreach (range(1, 3) as $index) {
            $user->notify(new JournalNotification);
        }

        $this->actingAs($user)->getJson('/api/v1/notifications?per_page=2')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.last_page', 2);

        $user->notifications()->first()->markAsRead();

        $this->actingAs($user)->getJson('/api/v1/notifications?unread=1')
            ->assertJsonCount(2, 'data');

        $this->actingAs($user)->getJson('/api/v1/notifications/unread-count')
            ->assertExactJson(['unread_count' => 2]);
    });

    it('marks specific notifications as read', function () {
        configurePush(false);
        $user = User::factory()->create();
        $other = User::factory()->create();

        $user->notify(new JournalNotification);
        $user->notify(new JournalNotification);
        $other->notify(new JournalNotification);

        $target = $user->notifications()->first()->id;
        $foreign = $other->notifications()->first()->id;

        $this->actingAs($user)->postJson('/api/v1/notifications/read', ['ids' => [$target, $foreign]])
            ->assertOk()
            ->assertExactJson(['marked' => 1, 'unread_count' => 1]);

        expect($other->unreadNotifications()->count())->toBe(1);
    });

    it('marks all notifications as read', function () {
        configurePush(false);
        $user = User::factory()->create();

        $user->notify(new JournalNotification);
        $user->notify(new JournalNotification);

        $this->actingAs($user)->postJson('/api/v1/notifications/read', ['all' => true])
            ->assertOk()
            ->assertExactJson(['marked' => 2, 'unread_count' => 0]);
    });

    it('requires ids or all when marking as read', function () {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/notifications/read', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('ids');
    });

    it('marks specific notifications as unread', function () {
        configurePush(false);
        $user = User::factory()->create();
        $other = User::factory()->create();

        $user->notify(new JournalNotification);
        $user->notify(new JournalNotification);
        $other->notify(new JournalNotification);
        $user->unreadNotifications->markAsRead();
        $other->unreadNotifications->markAsRead();

        $target = $user->notifications()->first()->id;
        $foreign = $other->notifications()->first()->id;

        $this->actingAs($user)->postJson('/api/v1/notifications/unread', ['ids' => [$target, $foreign]])
            ->assertOk()
            ->assertExactJson(['marked' => 1, 'unread_count' => 1]);

        expect($user->notifications()->find($target)->read_at)->toBeNull()
            ->and($other->unreadNotifications()->count())->toBe(0);
    });

    it('deletes specific notifications of the user only', function () {
        configurePush(false);
        $user = User::factory()->create();
        $other = User::factory()->create();

        $user->notify(new JournalNotification);
        $user->notify(new JournalNotification);
        $other->notify(new JournalNotification);

        $target = $user->notifications()->first()->id;
        $foreign = $other->notifications()->first()->id;

        $this->actingAs($user)->postJson('/api/v1/notifications/delete', ['ids' => [$target, $foreign]])
            ->assertOk()
            ->assertExactJson(['deleted' => 1, 'unread_count' => 1]);

        expect($user->notifications()->count())->toBe(1)
            ->and($other->notifications()->count())->toBe(1);
    });

    it('deletes only read notifications', function () {
        configurePush(false);
        $user = User::factory()->create();

        $user->notify(new JournalNotification);
        $user->notify(new JournalNotification);
        $user->notifications()->first()->markAsRead();

        $this->actingAs($user)->postJson('/api/v1/notifications/delete', ['read' => true])
            ->assertOk()
            ->assertExactJson(['deleted' => 1, 'unread_count' => 1]);

        expect($user->notifications()->count())->toBe(1);
    });

    it('deletes all notifications', function () {
        configurePush(false);
        $user = User::factory()->create();
        $other = User::factory()->create();

        $user->notify(new JournalNotification);
        $user->notify(new JournalNotification);
        $other->notify(new JournalNotification);

        $this->actingAs($user)->postJson('/api/v1/notifications/delete', ['all' => true])
            ->assertOk()
            ->assertExactJson(['deleted' => 2, 'unread_count' => 0]);

        expect($other->notifications()->count())->toBe(1);
    });

    it('requires ids, read or all when deleting', function () {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/notifications/delete', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('ids');
    });

    it('sends a test notification', function () {
        configurePush(false);
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/notifications/test')
            ->assertAccepted()
            ->assertExactJson(['channels' => ['database']]);

        expect($user->notifications()->count())->toBe(1);
    });

    it('includes push in the test notification when the user has a device', function () {
        Notification::fake();
        configurePush(true);
        $user = withDevice(User::factory()->create());

        $this->actingAs($user)->postJson('/api/v1/notifications/test')
            ->assertAccepted()
            ->assertExactJson(['channels' => ['database', ApnsChannel::class]]);

        Notification::assertSentTo($user, TestNotification::class);
    });
});

describe('channels contract', function () {
    it('uses manifest defaults when no preference is stored', function () {
        configurePush(true);
        $user = withDevice(User::factory()->create());

        expect(NotificationChannels::for($user, 'journal', 'daily_reminder'))->toBe(['database', ApnsChannel::class])
            ->and(NotificationChannels::for($user, 'journal', 'weekly_digest'))->toBe([]);
    });

    it('honours stored preferences', function () {
        configurePush(true);
        $user = withDevice(User::factory()->create());

        $user->notificationPreferences()->create(['module_id' => 'journal', 'type' => 'daily_reminder', 'push' => false, 'in_app' => true]);
        $user->notificationPreferences()->create(['module_id' => 'journal', 'type' => 'weekly_digest', 'push' => true, 'in_app' => false]);

        expect(NotificationChannels::for($user, 'journal', 'daily_reminder'))->toBe(['database'])
            ->and(NotificationChannels::for($user, 'journal', 'weekly_digest'))->toBe([ApnsChannel::class]);
    });

    it('omits push while apns is not configured', function () {
        configurePush(false);
        $user = withDevice(User::factory()->create());

        expect(NotificationChannels::for($user, 'journal', 'daily_reminder'))->toBe(['database']);
    });

    it('omits push for users without a registered device', function () {
        configurePush(true);
        $user = User::factory()->create();

        expect(NotificationChannels::for($user, 'journal', 'daily_reminder'))->toBe(['database']);
    });

    it('returns no channels for disabled or unknown modules', function () {
        configurePush(true);
        $user = User::factory()->create();
        $user->moduleSettings()->create(['module_id' => 'journal', 'enabled' => false]);

        expect(NotificationChannels::for($user, 'journal', 'daily_reminder'))->toBe([])
            ->and(NotificationChannels::for($user, 'unknown', 'anything'))->toBe([]);
    });

    it('falls back to the in-app inbox for undeclared types of a known module', function () {
        configurePush(true);
        $user = User::factory()->create();

        expect(NotificationChannels::for($user, 'journal', 'undeclared'))->toBe(['database']);
    });
});

describe('preferences endpoint', function () {
    it('returns preferences grouped by module with manifest labels', function () {
        configurePush(true);
        $user = User::factory()->create();

        $this->actingAs($user)->getJson('/api/v1/notification-preferences')
            ->assertOk()
            ->assertExactJson([
                'push_configured' => true,
                'data' => [[
                    'module' => 'journal',
                    'name' => 'Diario',
                    'icon' => 'book',
                    'enabled' => true,
                    'types' => [
                        ['type' => 'daily_reminder', 'label' => 'Recordatorio diario', 'description' => null, 'push' => true, 'in_app' => true, 'default_push' => true, 'default_in_app' => true],
                        ['type' => 'weekly_digest', 'label' => 'Resumen semanal', 'description' => null, 'push' => false, 'in_app' => false, 'default_push' => false, 'default_in_app' => false],
                    ],
                ]],
            ]);
    });

    it('updates preferences', function () {
        $user = User::factory()->create();

        $this->actingAs($user)->putJson('/api/v1/notification-preferences', [
            'preferences' => [
                ['module' => 'journal', 'type' => 'daily_reminder', 'push' => false, 'in_app' => true],
                ['module' => 'journal', 'type' => 'weekly_digest', 'push' => true, 'in_app' => true],
            ],
        ])
            ->assertOk()
            ->assertJsonPath('data.0.types.0.push', false)
            ->assertJsonPath('data.0.types.1.push', true)
            ->assertJsonPath('data.0.types.1.in_app', true);

        $this->actingAs($user)->putJson('/api/v1/notification-preferences', [
            'preferences' => [['module' => 'journal', 'type' => 'daily_reminder', 'push' => true, 'in_app' => true]],
        ])->assertOk();

        expect($user->notificationPreferences()->count())->toBe(2);
    });

    it('rejects unknown notification types', function () {
        $user = User::factory()->create();

        $this->actingAs($user)->putJson('/api/v1/notification-preferences', [
            'preferences' => [['module' => 'journal', 'type' => 'nope', 'push' => true, 'in_app' => true]],
        ])->assertUnprocessable()->assertJsonValidationErrors('preferences.0.type');
    });
});
