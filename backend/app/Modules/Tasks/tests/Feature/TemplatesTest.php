<?php

use App\Models\User;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;

beforeEach(function () {
    $this->travelTo(TaskCalendar::date('2026-10-26')->setTime(10, 0));
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

function moveTo(object $test, string $date): void
{
    $test->travelTo(TaskCalendar::date($date)->setTime(10, 0));
    app()->forgetScopedInstances();
}

function templateTasks(string $template): array
{
    return Task::query()->withoutGlobalScopes()->where('template_id', $template)->orderBy('occurrence_date')->get()
        ->map(fn (Task $task) => [$task->occurrence_date?->toDateString(), $task->status->value, $task->skip_reason?->value])
        ->all();
}

describe('editor', function () {
    it('previews the next five dates with a natural description', function () {
        $this->postJson('/api/v1/tasks/templates/preview', ['rrule' => 'FREQ=WEEKLY;INTERVAL=2;BYDAY=SA'])
            ->assertOk()
            ->assertExactJson(['data' => [
                'description' => 'Cada 2 semanas, el sábado',
                'ending' => null,
                'dates' => ['2026-10-31', '2026-11-14', '2026-11-28', '2026-12-12', '2026-12-26'],
            ]]);

        $this->postJson('/api/v1/tasks/templates/preview', ['after_done_interval_days' => 10, 'count' => 3])
            ->assertOk()
            ->assertJsonPath('data.description', '10 días después de completarla')
            ->assertJsonPath('data.ending', '3 veces')
            ->assertJsonPath('data.dates', ['2026-10-26', '2026-11-05', '2026-11-15']);

        $this->postJson('/api/v1/tasks/templates/preview', ['rrule' => 'FREQ=SECONDLY'])->assertUnprocessable();
        $this->postJson('/api/v1/tasks/templates/preview', [])->assertUnprocessable();
        $this->postJson('/api/v1/tasks/templates/preview', ['rrule' => 'FREQ=DAILY', 'after_done_interval_days' => 3])->assertUnprocessable();
    });

    it('creates a template and generates today\'s task with its subtasks', function () {
        $response = $this->postJson('/api/v1/tasks/templates', [
            'title' => 'Sacar la basura',
            'rrule' => 'FREQ=WEEKLY;BYDAY=MO,TH',
            'due_time' => '21:00',
            'subtasks' => ['Orgánico', 'Plástico'],
        ])->assertCreated();

        $response->assertJsonPath('data.kind', 'schedule')
            ->assertJsonPath('data.policy', 'replace')
            ->assertJsonPath('data.list.name', 'Bandeja')
            ->assertJsonPath('data.frequency_text', 'Cada lunes y jueves')
            ->assertJsonPath('data.dtstart', '2026-10-26')
            ->assertJsonPath('data.next_date', '2026-10-26')
            ->assertJsonPath('data.upcoming_dates', ['2026-10-29', '2026-11-02', '2026-11-05', '2026-11-09', '2026-11-12']);

        $this->getJson('/api/v1/tasks/today')
            ->assertJsonPath('data.today.0.title', 'Sacar la basura')
            ->assertJsonPath('data.today.0.due_time', '21:00')
            ->assertJsonPath('data.today.0.template.frequency_text', 'Cada lunes y jueves')
            ->assertJsonCount(2, 'data.today.0.subtasks');
    });
});

describe('generation', function () {
    it('replaces the open task and records skipped occurrences after a gap', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Regar', 'rrule' => 'FREQ=DAILY'])->json('data.id');

        moveTo($this, '2026-10-29');
        $this->artisan('tasks:generate')->assertSuccessful()->expectsOutputToContain('Tareas creadas: 1');

        expect(templateTasks($id))->toBe([
            ['2026-10-26', 'skipped', 'replaced'],
            ['2026-10-27', 'skipped', 'missed'],
            ['2026-10-28', 'skipped', 'missed'],
            ['2026-10-29', 'open', null],
        ]);

        $this->artisan('tasks:generate')->expectsOutputToContain('Tareas creadas: 0');
        expect(templateTasks($id))->toHaveCount(4);
    });

    it('accumulates every missed occurrence when asked to', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Pastilla', 'rrule' => 'FREQ=DAILY', 'policy' => 'accumulate'])->json('data.id');

        moveTo($this, '2026-10-28');

        $this->getJson('/api/v1/tasks/today')
            ->assertJsonCount(2, 'data.overdue')
            ->assertJsonCount(1, 'data.today');

        expect(array_column(templateTasks($id), 1))->toBe(['open', 'open', 'open']);
    });

    it('creates tasks ahead of time with lead days', function () {
        $this->postJson('/api/v1/tasks/templates', ['title' => 'Pagar IBI', 'rrule' => 'FREQ=YEARLY;BYMONTH=11;BYMONTHDAY=2', 'lead_days' => 7])
            ->assertCreated()
            ->assertJsonPath('data.frequency_text', 'Cada 2 de noviembre')
            ->assertJsonPath('data.next_date', '2026-11-02');

        $this->getJson('/api/v1/tasks/tasks')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.due_date', '2026-11-02');
    });

    it('schedules the next one from the completion day', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Cambiar sábanas', 'after_done_interval_days' => 10])
            ->assertJsonPath('data.kind', 'after_done')
            ->assertJsonPath('data.frequency_text', '10 días después de completarla')
            ->json('data.id');

        $task = $this->getJson('/api/v1/tasks/today')->json('data.today.0.id');

        moveTo($this, '2026-10-28');
        $this->postJson("/api/v1/tasks/tasks/{$task}/complete")->assertOk();
        $this->getJson("/api/v1/tasks/templates/{$id}")->assertJsonPath('data.next_date', '2026-11-07');

        moveTo($this, '2026-11-07');
        $next = $this->getJson('/api/v1/tasks/today')->assertJsonCount(1, 'data.today')->json('data.today.0.id');

        moveTo($this, '2026-11-09');
        $this->postJson("/api/v1/tasks/tasks/{$next}/skip")->assertOk();
        $this->getJson("/api/v1/tasks/templates/{$id}")->assertJsonPath('data.next_date', '2026-11-19');

        expect(array_column(templateTasks($id), 1))->toBe(['done', 'skipped']);
    });

    it('never has two open tasks for an after-done template', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Pelo', 'after_done_interval_days' => 1])->json('data.id');

        moveTo($this, '2026-11-10');
        $this->artisan('tasks:generate')->assertSuccessful();

        expect(templateTasks($id))->toBe([['2026-10-26', 'open', null]]);
    });

    it('stops at the end date and after the count', function () {
        $until = $this->postJson('/api/v1/tasks/templates', ['title' => 'A', 'rrule' => 'FREQ=DAILY', 'until' => '2026-10-27', 'policy' => 'accumulate'])->json('data.id');
        $count = $this->postJson('/api/v1/tasks/templates', ['title' => 'B', 'rrule' => 'FREQ=DAILY', 'count' => 2, 'policy' => 'accumulate'])->json('data.id');

        moveTo($this, '2026-10-30');
        $this->artisan('tasks:generate')->assertSuccessful();

        expect(templateTasks($until))->toHaveCount(2)
            ->and(templateTasks($count))->toHaveCount(2);
    });
});

describe('lifecycle', function () {
    it('pauses without generating and resumes from today', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Regar', 'rrule' => 'FREQ=DAILY', 'policy' => 'accumulate'])->json('data.id');

        $this->postJson("/api/v1/tasks/templates/{$id}/pause")->assertOk()->assertJsonPath('data.paused', true)->assertJsonPath('data.upcoming_dates', []);

        moveTo($this, '2026-10-29');
        $this->getJson('/api/v1/tasks/upcoming')->assertJsonPath('data.0.occurrences', []);
        expect(templateTasks($id))->toHaveCount(1);

        $this->postJson("/api/v1/tasks/templates/{$id}/resume")->assertOk()->assertJsonPath('data.paused', false);

        expect(templateTasks($id))->toBe([['2026-10-26', 'open', null], ['2026-10-29', 'open', null]]);
    });

    it('skips a single future occurrence and can undo it', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Basura', 'rrule' => 'FREQ=DAILY'])->json('data.id');

        $this->postJson("/api/v1/tasks/templates/{$id}/skip", ['date' => '2026-10-28'])->assertOk()
            ->assertJsonPath('data.skipped_dates', ['2026-10-28'])
            ->assertJsonPath('data.upcoming_dates', ['2026-10-27', '2026-10-29', '2026-10-30', '2026-10-31', '2026-11-01']);

        $this->postJson("/api/v1/tasks/templates/{$id}/skip", ['date' => '2026-10-29'])->assertOk();
        $this->postJson("/api/v1/tasks/templates/{$id}/unskip", ['date' => '2026-10-29'])->assertOk()->assertJsonPath('data.skipped_dates', ['2026-10-28']);

        moveTo($this, '2026-10-28');
        $this->artisan('tasks:generate')->assertSuccessful();

        expect(templateTasks($id))->toBe([
            ['2026-10-26', 'skipped', 'replaced'],
            ['2026-10-27', 'open', null],
            ['2026-10-28', 'skipped', 'manual'],
        ]);
    });

    it('skips the generated task when skipping today', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Basura', 'rrule' => 'FREQ=DAILY'])->json('data.id');

        $this->postJson("/api/v1/tasks/templates/{$id}/skip", ['date' => '2026-10-26'])->assertOk();

        expect(templateTasks($id))->toBe([['2026-10-26', 'skipped', 'manual']]);
    });

    it('applies edits to future occurrences and optionally to the open task', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Regar', 'rrule' => 'FREQ=DAILY'])->json('data.id');
        $done = $this->postJson('/api/v1/tasks/templates', ['title' => 'Leer', 'rrule' => 'FREQ=DAILY'])->json('data.id');
        $doneTask = Task::query()->where('template_id', $done)->value('id');
        $this->postJson("/api/v1/tasks/tasks/{$doneTask}/complete");

        $this->patchJson("/api/v1/tasks/templates/{$id}", ['title' => 'Regar plantas'])->assertOk();
        expect(Task::query()->where('template_id', $id)->value('title'))->toBe('Regar');

        $this->patchJson("/api/v1/tasks/templates/{$id}", ['title' => 'Regar las plantas', 'due_time' => '08:00', 'apply_to_open' => true])->assertOk();
        expect(Task::query()->where('template_id', $id)->first()?->only(['title', 'due_time']))->toBe(['title' => 'Regar las plantas', 'due_time' => '08:00:00']);

        $this->patchJson("/api/v1/tasks/templates/{$done}", ['title' => 'Leer mucho', 'apply_to_open' => true])->assertOk();
        expect(Task::query()->whereKey($doneTask)->value('title'))->toBe('Leer');

        $this->patchJson("/api/v1/tasks/templates/{$id}", ['after_done_interval_days' => 3])->assertOk()
            ->assertJsonPath('data.kind', 'after_done')
            ->assertJsonPath('data.rrule', null);
    });

    it('deletes a template keeping its tasks unless asked otherwise', function () {
        $keep = $this->postJson('/api/v1/tasks/templates', ['title' => 'A', 'rrule' => 'FREQ=DAILY'])->json('data.id');
        $drop = $this->postJson('/api/v1/tasks/templates', ['title' => 'B', 'rrule' => 'FREQ=DAILY'])->json('data.id');

        $this->deleteJson("/api/v1/tasks/templates/{$keep}")->assertNoContent();
        $this->deleteJson("/api/v1/tasks/templates/{$drop}?delete_open=1")->assertNoContent();

        expect(TaskTemplate::query()->count())->toBe(0)
            ->and(Task::query()->pluck('title')->all())->toBe(['A'])
            ->and(Task::query()->value('template_id'))->toBeNull();
    });

    it('keeps the history of every occurrence', function () {
        $id = $this->postJson('/api/v1/tasks/templates', ['title' => 'Correr', 'rrule' => 'FREQ=DAILY'])->json('data.id');

        foreach (['2026-10-27', '2026-10-28', '2026-10-30'] as $date) {
            moveTo($this, $date);
            $task = $this->getJson('/api/v1/tasks/today')->json('data.today.0.id');
            $this->postJson("/api/v1/tasks/tasks/{$task}/complete");
        }

        $this->getJson("/api/v1/tasks/templates/{$id}/history")
            ->assertOk()
            ->assertJsonPath('data.done', 3)
            ->assertJsonPath('data.window', 5)
            ->assertJsonPath('data.items.0.date', '2026-10-30')
            ->assertJsonPath('data.items.0.status', 'done')
            ->assertJsonPath('data.items.1.skip_reason', 'missed')
            ->assertJsonPath('data.items.4.skip_reason', 'replaced');
    });

    it('lists templates with their status', function () {
        $this->postJson('/api/v1/tasks/templates', ['title' => 'Zumo', 'rrule' => 'FREQ=MONTHLY;BYMONTHDAY=-1']);
        $paused = $this->postJson('/api/v1/tasks/templates', ['title' => 'Agua', 'rrule' => 'FREQ=DAILY'])->json('data.id');
        $this->postJson("/api/v1/tasks/templates/{$paused}/pause");

        $this->getJson('/api/v1/tasks/templates')
            ->assertOk()
            ->assertJsonPath('data.0.title', 'Zumo')
            ->assertJsonPath('data.0.frequency_text', 'El último día de cada mes')
            ->assertJsonPath('data.0.next_date', '2026-10-31')
            ->assertJsonPath('data.1.paused', true);
    });
});
