<?php

use App\Models\User;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;

beforeEach(function () {
    $this->travelTo(TaskCalendar::date('2026-10-26')->setTime(10, 0));
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

describe('lists', function () {
    it('creates the inbox on first use and keeps it first', function () {
        $this->postJson('/api/v1/tasks/lists', ['name' => 'Casa'])->assertCreated()->assertJsonPath('data.is_default', false);

        $this->getJson('/api/v1/tasks/lists')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Bandeja')
            ->assertJsonPath('data.0.is_default', true)
            ->assertJsonPath('data.0.open_tasks_count', 0)
            ->assertJsonPath('data.1.name', 'Casa');
    });

    it('renames, reorders, archives and protects the inbox', function () {
        $home = $this->postJson('/api/v1/tasks/lists', ['name' => 'Casa'])->json('data.id');
        $work = $this->postJson('/api/v1/tasks/lists', ['name' => 'Trabajo'])->json('data.id');
        $inbox = $this->getJson('/api/v1/tasks/lists')->json('data.0.id');

        $this->putJson('/api/v1/tasks/lists/order', ['ids' => [$work, $home]])->assertNoContent();
        $this->patchJson("/api/v1/tasks/lists/{$home}", ['name' => 'Hogar'])->assertOk()->assertJsonPath('data.name', 'Hogar');

        expect($this->getJson('/api/v1/tasks/lists')->json('data.*.name'))->toBe(['Bandeja', 'Trabajo', 'Hogar']);

        $this->patchJson("/api/v1/tasks/lists/{$work}", ['archived' => true])->assertOk()->assertJsonPath('data.archived', true);
        expect($this->getJson('/api/v1/tasks/lists')->json('data.*.name'))->toBe(['Bandeja', 'Hogar']);

        $this->patchJson("/api/v1/tasks/lists/{$inbox}", ['archived' => true])->assertUnprocessable();
        $this->deleteJson("/api/v1/tasks/lists/{$inbox}")->assertUnprocessable();
    });

    it('only deletes empty lists', function () {
        $list = $this->postJson('/api/v1/tasks/lists', ['name' => 'Casa'])->json('data.id');
        $task = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Fregar', 'list_id' => $list])->json('data.id');

        $this->deleteJson("/api/v1/tasks/lists/{$list}")->assertUnprocessable();
        $this->deleteJson("/api/v1/tasks/tasks/{$task}")->assertNoContent();
        $this->deleteJson("/api/v1/tasks/lists/{$list}")->assertNoContent();
    });
});

describe('tasks', function () {
    it('quick adds to the inbox with a date and subtasks', function () {
        $this->postJson('/api/v1/tasks/tasks', [
            'title' => '  Llamar al fontanero ',
            'due_date' => '2026-10-27',
            'due_time' => '09:30',
            'subtasks' => ['Buscar teléfono', 'Pedir presupuesto'],
        ])
            ->assertCreated()
            ->assertJsonPath('data.title', 'Llamar al fontanero')
            ->assertJsonPath('data.list.name', 'Bandeja')
            ->assertJsonPath('data.due_date', '2026-10-27')
            ->assertJsonPath('data.due_time', '09:30')
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.overdue', false)
            ->assertJsonPath('data.subtasks.1.title', 'Pedir presupuesto')
            ->assertJsonPath('data.subtasks_done', 0);
    });

    it('drops the time when the task has no date', function () {
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Algún día', 'due_time' => '10:00'])
            ->assertCreated()
            ->assertJsonPath('data.due_time', null);
    });

    it('completes, undoes, postpones and skips', function () {
        $id = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Basura', 'due_date' => '2026-10-24'])->json('data.id');

        $this->getJson("/api/v1/tasks/tasks/{$id}")->assertJsonPath('data.overdue', true);

        $this->postJson("/api/v1/tasks/tasks/{$id}/complete")->assertOk()
            ->assertJsonPath('data.status', 'done')
            ->assertJsonPath('data.overdue', false)
            ->assertJsonPath('data.completed_at', now()->toIso8601String());

        $this->postJson("/api/v1/tasks/tasks/{$id}/reopen")->assertOk()
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.completed_at', null);

        $this->postJson("/api/v1/tasks/tasks/{$id}/postpone", ['date' => '2026-10-31'])->assertOk()
            ->assertJsonPath('data.due_date', '2026-10-31');

        $this->postJson("/api/v1/tasks/tasks/{$id}/skip")->assertOk()
            ->assertJsonPath('data.status', 'skipped')
            ->assertJsonPath('data.skip_reason', 'manual');
    });

    it('edits and checks off subtasks without completing the task', function () {
        $task = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Maleta', 'subtasks' => ['Cargador']])->json('data');
        $subtask = $task['subtasks'][0]['id'];

        $this->patchJson("/api/v1/tasks/tasks/{$task['id']}/subtasks/{$subtask}", ['done' => true])->assertOk()->assertJsonPath('data.done', true);
        $this->postJson("/api/v1/tasks/tasks/{$task['id']}/subtasks", ['title' => 'Pasaporte'])->assertCreated()->assertJsonPath('data.sort', 1);

        $this->getJson("/api/v1/tasks/tasks/{$task['id']}")
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.subtasks_done', 1)
            ->assertJsonCount(2, 'data.subtasks');

        $this->deleteJson("/api/v1/tasks/tasks/{$task['id']}/subtasks/{$subtask}")->assertNoContent();
        $this->getJson("/api/v1/tasks/tasks/{$task['id']}")->assertJsonCount(1, 'data.subtasks');
    });

    it('updates title, notes, list, date and importance', function () {
        $list = $this->postJson('/api/v1/tasks/lists', ['name' => 'Personal'])->json('data.id');
        $id = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Leer', 'due_date' => '2026-10-26', 'due_time' => '20:00'])->json('data.id');

        $this->patchJson("/api/v1/tasks/tasks/{$id}", ['title' => 'Leer un rato', 'notes' => 'Capítulo 3', 'list_id' => $list, 'important' => true, 'due_date' => null])
            ->assertOk()
            ->assertJsonPath('data.title', 'Leer un rato')
            ->assertJsonPath('data.notes', 'Capítulo 3')
            ->assertJsonPath('data.list.name', 'Personal')
            ->assertJsonPath('data.important', true)
            ->assertJsonPath('data.due_date', null)
            ->assertJsonPath('data.due_time', null);
    });

    it('filters by list, status and text', function () {
        $home = $this->postJson('/api/v1/tasks/lists', ['name' => 'Casa'])->json('data.id');
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Regar plantas', 'list_id' => $home]);
        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Comprar pan']);
        $done = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Regar huerto', 'list_id' => $home])->json('data.id');
        $this->postJson("/api/v1/tasks/tasks/{$done}/complete");

        expect($this->getJson("/api/v1/tasks/tasks?list_id={$home}")->json('data.*.title'))->toBe(['Regar plantas'])
            ->and($this->getJson('/api/v1/tasks/tasks?status=done')->json('data.*.title'))->toBe(['Regar huerto'])
            ->and($this->getJson('/api/v1/tasks/tasks?status=all&q=regar')->json('data.*.title'))->toEqualCanonicalizing(['Regar plantas', 'Regar huerto'])
            ->and($this->getJson('/api/v1/tasks/tasks?status=done&from=2026-10-27')->json('data'))->toBe([]);
    });

    it('keeps tasks private to their owner', function () {
        $id = $this->postJson('/api/v1/tasks/tasks', ['title' => 'Secreto'])->json('data.id');
        $other = User::factory()->create();

        $this->actingAs($other)->getJson("/api/v1/tasks/tasks/{$id}")->assertNotFound();
        $this->actingAs($other)->postJson("/api/v1/tasks/tasks/{$id}/complete")->assertNotFound();
        $this->actingAs($other)->getJson('/api/v1/tasks/tasks')->assertJsonCount(0, 'data');

        $foreignList = $this->actingAs($this->user)->getJson('/api/v1/tasks/lists')->json('data.0.id');
        $this->actingAs($other)->postJson('/api/v1/tasks/tasks', ['title' => 'X', 'list_id' => $foreignList])->assertUnprocessable();

        expect(Task::query()->withoutGlobalScopes()->count())->toBe(1);
    });

    it('is blocked when the module is disabled', function () {
        $this->patchJson('/api/v1/modules/tasks', ['enabled' => false])->assertOk();

        $this->getJson('/api/v1/tasks/today')->assertForbidden();
    });

    it('uses the default list from the module settings', function () {
        $home = $this->postJson('/api/v1/tasks/lists', ['name' => 'Casa'])->json('data.id');
        $this->patchJson('/api/v1/modules/tasks', ['settings' => ['default_list_id' => $home]])->assertOk();

        $this->postJson('/api/v1/tasks/tasks', ['title' => 'Barrer'])->assertJsonPath('data.list_id', $home);
    });
});
