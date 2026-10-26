<?php

namespace App\Modules\Tasks\Domain\Services;

use App\Models\User;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskList;
use App\Modules\Tasks\Models\TaskTemplate;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class TaskListService
{
    /** @var array<string, TaskList> */
    private array $defaults = [];

    public function defaultFor(User $user): TaskList
    {
        if (isset($this->defaults[$user->id])) {
            return $this->defaults[$user->id];
        }

        $list = TaskList::query()->ownedBy($user)->where('is_default', true)->first();

        if ($list === null) {
            DB::statement('INSERT INTO tasks.task_lists (id, user_id, name, is_default, sort_order, created_at, updated_at) VALUES (gen_random_uuid(), ?, ?, true, 0, now(), now()) ON CONFLICT DO NOTHING', [$user->id, TaskList::DEFAULT_NAME]);
            $list = TaskList::query()->ownedBy($user)->where('is_default', true)->firstOrFail();
        }

        return $this->defaults[$user->id] = $list;
    }

    /**
     * @param  array{name: string, color?: string|null, icon?: string|null}  $data
     */
    public function create(User $user, array $data): TaskList
    {
        $this->defaultFor($user);

        $list = new TaskList([
            'name' => trim($data['name']),
            'color' => $data['color'] ?? null,
            'icon' => $data['icon'] ?? null,
            'sort_order' => (int) TaskList::query()->ownedBy($user)->max('sort_order') + 1,
        ]);
        $list->user_id = $user->id;
        $list->save();

        return $list;
    }

    /**
     * @param  array{name?: string, color?: string|null, icon?: string|null, archived?: bool}  $data
     */
    public function update(TaskList $list, array $data): TaskList
    {
        if (array_key_exists('archived', $data)) {
            if ($list->is_default && $data['archived']) {
                throw ValidationException::withMessages(['archived' => 'La Bandeja no se puede archivar.']);
            }

            $list->archived_at = $data['archived'] ? ($list->archived_at ?? now()->toImmutable()) : null;
            unset($data['archived']);
        }

        if (isset($data['name'])) {
            $data['name'] = trim($data['name']);
        }

        $list->fill($data)->save();

        return $list;
    }

    /**
     * @param  list<string>  $ids
     */
    public function reorder(User $user, array $ids): void
    {
        DB::transaction(function () use ($user, $ids): void {
            foreach ($ids as $position => $id) {
                TaskList::query()->ownedBy($user)->whereKey($id)->update(['sort_order' => $position + 1]);
            }
        });
    }

    public function delete(TaskList $list): void
    {
        if ($list->is_default) {
            throw ValidationException::withMessages(['list' => 'La Bandeja no se puede borrar.']);
        }

        $inUse = Task::query()->withoutGlobalScopes()->where('list_id', $list->id)->exists()
            || TaskTemplate::query()->withoutGlobalScopes()->where('list_id', $list->id)->exists();

        if ($inUse) {
            throw ValidationException::withMessages(['list' => 'La lista tiene tareas o plantillas. Archívala en lugar de borrarla.']);
        }

        $list->delete();
    }
}
