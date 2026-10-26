<?php

use App\Core\Pending\PendingDigestNotification;
use App\Models\User;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    $this->travelTo(TaskCalendar::date('2026-10-26')->setTime(10, 0));
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

describe('today', function () {
    it('groups overdue, today and done today with the day progress', function () {
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Vencida', 'due_date' => '2026-10-20']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Normal', 'due_date' => '2026-10-26']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Con hora', 'due_date' => '2026-10-26', 'due_time' => '08:00']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Importante', 'due_date' => '2026-10-26', 'important' => true]);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Mañana', 'due_date' => '2026-10-27']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Sin fecha']);
        $done = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Hecha', 'due_date' => '2026-10-26'])->json('data.id');
        $this->postJson("/api/v1/tasks/tasks/{$done}/complete");

        $response = $this->getJson('/api/v1/tasks/today')->assertOk()
            ->assertJsonPath('data.date', '2026-10-26')
            ->assertJsonPath('data.progress', ['done' => 1, 'total' => 4]);

        expect($response->json('data.overdue.*.title'))->toBe(['Vencida'])
            ->and($response->json('data.today.*.title'))->toBe(['Importante', 'Con hora', 'Normal'])
            ->and($response->json('data.done.*.title'))->toBe(['Hecha']);
    });
});

describe('upcoming', function () {
    it('shows dated tasks and virtual occurrences for 14 days', function () {
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Dentista', 'due_date' => '2026-10-28']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Lejos', 'due_date' => '2026-11-20']);
        $template = $this->postJson('/api/v1/tasks/templates', ['title' => 'Basura', 'rrule' => 'FREQ=WEEKLY;BYDAY=MO,TH'])->json('data.id');
        $this->postJson('/api/v1/tasks/templates', ['title' => 'Sábanas', 'after_done_interval_days' => 10]);
        $this->postJson("/api/v1/tasks/templates/{$template}/skip", ['date' => '2026-11-02']);

        $days = $this->getJson('/api/v1/tasks/upcoming')->assertOk()->assertJsonCount(14, 'data')->json('data');

        expect($days[0]['date'])->toBe('2026-10-26')
            ->and(array_column($days[0]['tasks'], 'title'))->toBe(['Basura', 'Sábanas'])
            ->and($days[0]['occurrences'])->toBe([])
            ->and(array_column($days[2]['tasks'], 'title'))->toBe(['Dentista'])
            ->and($days[3]['occurrences'][0])->toMatchArray(['template_id' => $template, 'date' => '2026-10-29', 'title' => 'Basura', 'frequency_text' => 'Cada lunes y jueves'])
            ->and($days[7]['occurrences'])->toBe([])
            ->and(collect($days)->flatMap(fn (array $day) => array_column($day['occurrences'], 'date'))->all())
            ->toBe(['2026-10-29', '2026-11-05']);
    });
});

describe('pending', function () {
    it('lists only overdue tasks in the shared pending inbox', function () {
        $overdue = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Pagar multa', 'due_date' => '2026-10-24'])->json('data.id');
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Hoy', 'due_date' => '2026-10-26']);

        $this->getJson('/api/v1/pending/summary')
            ->assertOk()
            ->assertJsonPath('data.by_module', [
                ['module' => 'tasks', 'module_name' => 'Tareas', 'type' => 'overdue_task', 'count' => 1],
            ]);

        $this->getJson('/api/v1/pending?module=tasks')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0', [
                'module' => 'tasks',
                'type' => 'overdue_task',
                'id' => $overdue,
                'title' => 'Pagar multa',
                'subtitle' => 'Bandeja',
                'amount_cents' => null,
                'date' => '2026-10-24',
                'route' => '/tareas/hoy',
                'meta' => ['task_id' => $overdue, 'list_id' => $this->getJson('/api/v1/tasks/lists')->json('data.0.id'), 'template_id' => null, 'due_time' => null, 'important' => false],
            ]);
    });

    it('mentions the open tasks of the day in the 20:00 digest', function () {
        Notification::fake();
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Vencida', 'due_date' => '2026-10-24']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Hoy 1', 'due_date' => '2026-10-26']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Hoy 2', 'due_date' => '2026-10-26']);

        $this->artisan('core:pending-digest', ['--date' => '2026-10-26'])->expectsOutputToContain('Notificaciones enviadas: 1');

        Notification::assertSentTo($this->user, PendingDigestNotification::class, fn (PendingDigestNotification $notification) => $notification->total === 3
            && $notification->body() === 'Tienes 1 tarea vencida y 2 tareas de hoy por hacer');
    });

    it('sends the digest when only today\'s tasks are open', function () {
        Notification::fake();
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Hoy', 'due_date' => '2026-10-26']);

        $this->artisan('core:pending-digest', ['--date' => '2026-10-26'])->expectsOutputToContain('Notificaciones enviadas: 1');
        $this->getJson('/api/v1/pending/summary')->assertJsonPath('data.total', 0);
    });

    it('finds tasks and templates in the global search', function () {
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Comprar pintura', 'due_date' => '2026-10-27']);
        $this->postJson('/api/v1/tasks/templates', ['title' => 'Pintar valla', 'rrule' => 'FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=1']);

        $results = $this->getJson('/api/v1/search?q=pint')->assertOk()->json('data');

        expect(collect($results)->pluck('title')->all())->toContain('Comprar pintura', 'Pintar valla');
    });

    it('schedules the daily generation right after midnight', function () {
        $event = collect(app(Schedule::class)->events())
            ->first(fn ($event) => str_contains((string) $event->command, 'tasks:generate'));

        expect($event?->expression)->toBe('5 0 * * *')
            ->and($event?->timezone)->toBe('Europe/Madrid');
    });
});
