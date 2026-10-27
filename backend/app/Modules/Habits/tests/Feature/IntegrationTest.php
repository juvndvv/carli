<?php

use App\Core\Pending\PendingDigestNotification;
use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Tasks\Domain\Enums\SkipReason;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    $this->travelTo(HabitCalendar::date('2026-10-31')->setTime(19, 0));
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

function digestHabit(array $data): string
{
    return test()->postJson('/api/v1/habits', $data + ['icon' => 'check', 'kind' => 'check', 'period' => 'day', 'start_date' => '2026-10-26'])->assertCreated()->json('data.id');
}

/**
 * @param  array<string, string>  $history  date => done|manual|missed|open
 */
function templateWithHistory(string $rrule, array $history): string
{
    $id = test()->postJson('/api/v1/tasks/templates', ['title' => 'Meditar 10 min', 'rrule' => $rrule, 'subtasks' => ['Respirar']])->assertCreated()->json('data.id');
    $template = TaskTemplate::query()->findOrFail($id);
    $template->tasks()->delete();

    foreach ($history as $date => $state) {
        $task = new Task([
            'list_id' => $template->list_id,
            'template_id' => $template->id,
            'occurrence_date' => $date,
            'due_date' => $date,
            'title' => $template->title,
            'status' => match ($state) {
                'done' => TaskStatus::Done->value,
                'open' => TaskStatus::Open->value,
                default => TaskStatus::Skipped->value,
            },
            'skip_reason' => match ($state) {
                'manual' => SkipReason::Manual->value,
                'missed' => SkipReason::Missed->value,
                default => null,
            },
        ]);
        $task->user_id = test()->user->id;
        $task->save();
    }

    return $id;
}

describe('20:00 digest', function () {
    it('adds the habits line to the single daily notification', function () {
        Notification::fake();
        digestHabit(['name' => 'Meditar']);
        digestHabit(['name' => 'Leer']);
        $run = digestHabit(['name' => 'Correr', 'period' => 'week', 'target' => 3]);
        $this->putJson("/api/v1/habits/{$run}/entries/2026-10-28", ['value' => 1]);
        digestHabit(['name' => 'Tabaco', 'kind' => 'avoid']);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Pagar', 'due_date' => '2026-10-31']);

        $this->artisan('core:pending-digest', ['--date' => '2026-10-31'])->expectsOutputToContain('Notificaciones enviadas: 1');

        Notification::assertSentTo($this->user, PendingDigestNotification::class, fn (PendingDigestNotification $notification) => $notification->body() === 'Tienes 1 tarea de hoy por hacer. Te quedan 2 hábitos de hoy. Correr: 1 de 3, quedan 2 días'
            && $notification->title() === 'Pendientes por revisar');
    });

    it('sends a habits-only notification when nothing else is pending', function () {
        Notification::fake();
        digestHabit(['name' => 'Meditar']);

        $this->artisan('core:pending-digest', ['--date' => '2026-10-31'])->expectsOutputToContain('Notificaciones enviadas: 1');

        Notification::assertSentTo($this->user, PendingDigestNotification::class, fn (PendingDigestNotification $notification) => $notification->body() === 'Te queda 1 hábito de hoy'
            && $notification->title() === 'Hábitos de hoy'
            && $notification->toArray($this->user)['url'] === '/habitos/hoy');
    });

    it('leaves weekly goals out while they are not at risk and when they are met', function () {
        Notification::fake();
        $this->travelTo(HabitCalendar::date('2026-10-28')->setTime(19, 0));
        digestHabit(['name' => 'Correr', 'period' => 'week', 'target' => 3]);
        $met = digestHabit(['name' => 'Nadar', 'period' => 'week', 'target' => 1]);
        $this->putJson("/api/v1/habits/{$met}/entries/2026-10-27", ['value' => 1]);

        $this->artisan('core:pending-digest', ['--date' => '2026-10-28'])->expectsOutputToContain('Notificaciones enviadas: 0');
    });

    it('can be switched off in the module settings', function () {
        Notification::fake();
        digestHabit(['name' => 'Meditar']);
        $this->patchJson('/api/v1/modules/habits', ['settings' => ['digest' => false]])->assertOk();

        $this->artisan('core:pending-digest', ['--date' => '2026-10-31'])->expectsOutputToContain('Notificaciones enviadas: 0');
        Notification::assertNothingSent();
    });

    it('stays silent when the module is disabled', function () {
        Notification::fake();
        digestHabit(['name' => 'Meditar']);
        $this->patchJson('/api/v1/modules/habits', ['enabled' => false])->assertOk();

        $this->artisan('core:pending-digest', ['--date' => '2026-10-31'])->expectsOutputToContain('Notificaciones enviadas: 0');
    });
});

describe('convert a template', function () {
    it('previews the goal and the imported history', function () {
        $template = templateWithHistory('FREQ=DAILY', [
            '2026-10-26' => 'done', '2026-10-27' => 'done', '2026-10-28' => 'manual', '2026-10-29' => 'missed', '2026-10-30' => 'done', '2026-10-31' => 'open',
        ]);

        $preview = $this->getJson("/api/v1/habits/conversions/{$template}")->assertOk();

        expect($preview->json('data'))->toMatchArray([
            'template_id' => $template,
            'name' => 'Meditar 10 min',
            'start_date' => '2026-10-26',
            'goal' => ['period' => 'day', 'target' => 1, 'days_of_week' => null],
            'goal_text' => 'Cada día',
            'done' => 3,
            'skipped' => 1,
            'missed' => 1,
            'consistency' => 75,
            'streak' => 1,
        ])->and($preview->json('data.cells'))->toHaveCount(56);
    });

    it('creates the habit, imports the history, pauses the template and deletes its open task', function () {
        $template = templateWithHistory('FREQ=WEEKLY;BYDAY=MO,WE,FR', [
            '2026-10-19' => 'done', '2026-10-21' => 'manual', '2026-10-23' => 'done', '2026-10-26' => 'missed', '2026-10-28' => 'done', '2026-10-30' => 'open',
        ]);

        $response = $this->postJson('/api/v1/habits/conversions', ['template_id' => $template, 'icon' => 'leaf'])->assertCreated();

        $response->assertJsonPath('data.name', 'Meditar 10 min')
            ->assertJsonPath('data.icon', 'leaf')
            ->assertJsonPath('data.start_date', '2026-10-19')
            ->assertJsonPath('data.converted_from_template_id', $template)
            ->assertJsonPath('data.goal.days_of_week', [1, 3, 5])
            ->assertJsonPath('data.goal_text', 'Lunes, miércoles y viernes')
            ->assertJsonPath('data.stats.streak', 0);

        $id = $response->json('data.id');
        $days = collect($this->getJson("/api/v1/habits/{$id}/calendar?month=2026-10")->json('data.days'))->keyBy('date');

        expect($days['2026-10-19']['state'])->toBe('done')
            ->and($days['2026-10-21']['state'])->toBe('rest')
            ->and($days['2026-10-26']['state'])->toBe('miss')
            ->and($days['2026-10-30']['state'])->toBe('miss')
            ->and(DB::table('habits.habit_entries')->pluck('source')->unique()->all())->toBe(['task_import'])
            ->and(TaskTemplate::query()->findOrFail($template)->isPaused())->toBeTrue()
            ->and(Task::query()->where('template_id', $template)->where('status', 'open')->count())->toBe(0)
            ->and(Task::query()->where('template_id', $template)->count())->toBe(5);

        $this->getJson('/api/v1/tasks/today')->assertJsonPath('data.today', []);
    });

    it('refuses templates that are not daily or weekly', function (array $frequency) {
        $template = $this->postJson('/api/v1/tasks/templates', ['title' => 'Comunidad'] + $frequency)->assertCreated()->json('data.id');

        $this->getJson("/api/v1/habits/conversions/{$template}")->assertJsonValidationErrors('template_id');
        $this->postJson('/api/v1/habits/conversions', ['template_id' => $template])->assertJsonValidationErrors('template_id');
        expect(TaskTemplate::query()->findOrFail($template)->isPaused())->toBeFalse();
    })->with([
        'monthly' => [['rrule' => 'FREQ=MONTHLY;BYMONTHDAY=1']],
        'every other week' => [['rrule' => 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO']],
        'after done' => [['after_done_interval_days' => 10]],
    ]);

    it('does not convert templates of other users', function () {
        $template = templateWithHistory('FREQ=DAILY', []);
        $this->actingAs(User::factory()->create());

        $this->getJson("/api/v1/habits/conversions/{$template}")->assertNotFound();
        $this->postJson('/api/v1/habits/conversions', ['template_id' => $template])->assertNotFound();
    });
});
