<?php

use App\Core\Pending\PendingDigestNotification;
use App\Models\User;
use App\Modules\Calendar\Domain\CalendarClock;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Notifications\TaskDue;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Notification;

require_once __DIR__.'/../Support/GoogleFakes.php';

beforeEach(function () {
    $this->travelTo(CalendarClock::date('2026-11-03')->setTime(10, 0));
    config([
        'services.google.client_id' => 'client-id.apps.googleusercontent.com',
        'services.google.client_secret' => 'secret',
    ]);
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
    $GLOBALS['carli_google_faked'] = false;
});

/**
 * @return list<array<string, mixed>>
 */
function calendarItems(object $test, string $from, string $to, ?string $source = null): array
{
    $items = $test->getJson("/api/v1/calendar?from={$from}&to={$to}")->assertOk()->json('data.items');

    return array_values(array_filter($items, fn (array $item) => $source === null || $item['source'] === $source));
}

describe('range', function () {
    it('validates the range', function () {
        $this->getJson('/api/v1/calendar?from=2026-11-10&to=2026-11-01')->assertJsonValidationErrors('to');
        $this->getJson('/api/v1/calendar?from=2026-11-01&to=2027-01-15')->assertJsonValidationErrors('to');
        $this->getJson('/api/v1/calendar')->assertJsonValidationErrors(['from', 'to']);
    });

    it('is off when the module is disabled', function () {
        $this->patchJson('/api/v1/modules/calendar', ['enabled' => false])->assertOk();

        $this->getJson('/api/v1/calendar?from=2026-11-01&to=2026-11-07')->assertForbidden();
    });
});

describe('google events', function () {
    it('shows timed events, spreads multi-day ones and sorts all-day first', function () {
        fakeGoogle(googleEvents());
        connectGoogle($this);

        $items = calendarItems($this, '2026-11-04', '2026-11-08', 'google');

        expect(array_map(fn ($item) => [$item['date'], $item['time'], $item['end_time'], $item['title'], $item['subtitle']], $items))->toBe([
            ['2026-11-04', '09:30', '10:15', 'Dentista', 'Calle Mayor 3'],
            ['2026-11-04', '21:00', '00:00', 'Cena familiar', null],
            ['2026-11-05', '18:00', '18:30', 'Llamada', null],
            ['2026-11-06', null, null, 'Viaje a Lisboa', null],
            ['2026-11-07', null, null, 'Viaje a Lisboa', 'Continúa'],
            ['2026-11-08', null, null, 'Viaje a Lisboa', 'Continúa'],
        ])
            ->and($items[0]['color'])->toBe('#9fe1e7')
            ->and($items[0]['meta']['calendar'])->toBe('juanda@jotade.io')
            ->and($items[0]['meta']['html_link'])->toBe('https://calendar.google.com/e/dentist')
            ->and($items[3]['id'])->toEndWith(':2026-11-06');
    });

    it('queues a refresh when the copy is old', function () {
        fakeGoogle(googleEvents());
        connectGoogle($this);
        $this->travel(10)->minutes();
        fakeGoogle();

        $this->getJson('/api/v1/calendar?from=2026-11-04&to=2026-11-04')->assertOk();

        // The queue runs synchronously in tests: the refresh already emptied the calendar.
        expect(calendarItems($this, '2026-11-04', '2026-11-04', 'google'))->toBe([]);
    });

    it('mentions tomorrow\'s events in the 20:00 digest', function () {
        Notification::fake();
        fakeGoogle(googleEvents());
        connectGoogle($this);

        $this->artisan('core:pending-digest', ['--date' => '2026-11-03'])->assertSuccessful();

        Notification::assertSentTo($this->user, PendingDigestNotification::class, fn (PendingDigestNotification $notification) => in_array('Mañana tienes 2 eventos, el primero a las 09:30 (Dentista)', $notification->lines, true));
    });
});

describe('carli items', function () {
    it('shows open and done tasks on their day and template dates still to come', function () {
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Vencida', 'due_date' => '2026-11-02']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Llamar al banco', 'due_date' => '2026-11-04', 'due_time' => '16:30', 'important' => true]);
        $done = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Hecha', 'due_date' => '2026-11-03'])->json('data.id');
        $this->postJson("/api/v1/tasks/tasks/{$done}/complete");
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Sin fecha']);
        $this->postJson('/api/v1/tasks/templates', ['title' => 'Basura', 'rrule' => 'FREQ=WEEKLY;BYDAY=TH']);

        $tasks = calendarItems($this, '2026-11-02', '2026-11-13', 'tasks');
        $templates = calendarItems($this, '2026-11-02', '2026-11-13', 'templates');

        expect(array_map(fn ($item) => [$item['date'], $item['title'], $item['done'], $item['meta']['overdue']], $tasks))->toBe([
            ['2026-11-02', 'Vencida', false, true],
            ['2026-11-03', 'Hecha', true, false],
            ['2026-11-04', 'Llamar al banco', false, false],
        ])
            ->and($tasks[2]['time'])->toBe('16:30')
            ->and($tasks[2]['url'])->toBe('/tareas/tarea/'.$tasks[2]['id'])
            ->and(array_column($templates, 'date'))->toBe(['2026-11-05', '2026-11-12'])
            ->and($templates[0]['url'])->toStartWith('/tareas/plantillas/');
    });

    it('shows the recurring charges from today on', function () {
        $account = F::account($this->user);
        $this->postJson('/api/v1/finance/recurring-rules', [
            'account_id' => $account->id, 'kind' => 'expense', 'amount_cents' => 1399, 'payee' => 'Netflix',
            'frequency' => 'monthly', 'start_date' => '2026-10-05', 'mode' => 'auto', 'is_subscription' => true,
        ])->assertCreated();

        $items = calendarItems($this, '2026-10-01', '2026-11-30', 'finance');

        expect(array_map(fn ($item) => [$item['date'], $item['title'], $item['subtitle']], $items))->toBe([
            ['2026-11-05', 'Netflix', '−13,99 € · suscripción'],
        ]);
    });

    it('shows weigh-ins done and the reminder days ahead', function () {
        $this->putJson('/api/v1/health/settings', ['reminder_enabled' => true, 'reminder_time' => '07:30', 'reminder_days' => [3, 5]])->assertOk();
        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 137.4, 'measured_at' => '2026-11-03T07:05:00+01:00'])->assertCreated();

        $items = calendarItems($this, '2026-11-02', '2026-11-08', 'health');

        expect(array_map(fn ($item) => [$item['date'], $item['time'], $item['title'], $item['done'], $item['subtitle']], $items))->toBe([
            ['2026-11-03', '07:05', 'Pesada', true, '137,4 kg'],
            ['2026-11-04', '07:30', 'Pesarse', false, 'Recordatorio'],
            ['2026-11-06', '07:30', 'Pesarse', false, 'Recordatorio'],
        ]);
    });

    it('sums each day\'s habits up to today', function () {
        $meditate = $this->postJson('/api/v1/habits', ['name' => 'Meditar', 'icon' => 'check', 'kind' => 'check', 'period' => 'day', 'start_date' => '2026-11-01'])->assertCreated()->json('data.id');
        $this->postJson('/api/v1/habits', ['name' => 'Leer', 'icon' => 'check', 'kind' => 'check', 'period' => 'day', 'start_date' => '2026-11-01'])->assertCreated();
        $this->putJson("/api/v1/habits/{$meditate}/entries/2026-11-02", ['value' => 1])->assertOk();

        $items = calendarItems($this, '2026-11-01', '2026-11-05', 'habits');

        expect(array_map(fn ($item) => [$item['date'], $item['subtitle'], $item['done']], $items))->toBe([
            ['2026-11-01', '0 de 2', false],
            ['2026-11-02', '1 de 2', false],
            ['2026-11-03', '0 de 2', false],
        ]);
    });
});

describe('task reminders', function () {
    it('pushes a task when its time comes, once', function () {
        Notification::fake();
        configureApns(true);
        $this->user->pushDevices()->create(['token' => str_repeat('ab', 32), 'environment' => 'sandbox']);
        $id = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Llamar al banco', 'due_date' => '2026-11-03', 'due_time' => '10:30'])->json('data.id');
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Sin hora', 'due_date' => '2026-11-03']);
        $done = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Hecha', 'due_date' => '2026-11-03', 'due_time' => '10:30'])->json('data.id');
        $this->postJson("/api/v1/tasks/tasks/{$done}/complete");

        $this->artisan('tasks:due-reminders')->expectsOutputToContain('Avisos enviados: 0');
        $this->travelTo(CalendarClock::date('2026-11-03')->setTime(10, 30, 20));
        $this->artisan('tasks:due-reminders')->expectsOutputToContain('Avisos enviados: 1');
        $this->artisan('tasks:due-reminders')->expectsOutputToContain('Avisos enviados: 0');

        Notification::assertSentToTimes($this->user, TaskDue::class, 1);
        Notification::assertSentTo($this->user, TaskDue::class, fn (TaskDue $notification) => $notification->taskId === $id
            && $notification->toArray($this->user)['body'] === 'Tarea para las 10:30'
            && $notification->toArray($this->user)['url'] === "/tareas/tarea/{$id}");
    });

    it('catches up a missed minute but not an old time, and reminds again after a new time', function () {
        Notification::fake();
        $id = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Regar', 'due_date' => '2026-11-03', 'due_time' => '09:00'])->json('data.id');
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Casi', 'due_date' => '2026-11-03', 'due_time' => '09:55']);

        $this->artisan('tasks:due-reminders')->expectsOutputToContain('Avisos enviados: 1');

        $this->patchJson("/api/v1/tasks/tasks/{$id}", ['due_time' => '10:05'])->assertOk();
        expect(Task::query()->find($id)?->reminded_at)->toBeNull();
        $this->travel(5)->minutes();
        $this->artisan('tasks:due-reminders')->expectsOutputToContain('Avisos enviados: 1');
    });

    it('runs every minute', function () {
        $event = collect(app(Schedule::class)->events())->first(fn ($event) => str_contains((string) $event->command, 'tasks:due-reminders'));

        expect($event?->expression)->toBe('* * * * *');
    });
});
