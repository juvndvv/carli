<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Domain\Sync\OperationRejected;
use App\Modules\Notes\Models\Folder;

final class FolderUpsert extends Handler
{
    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, [
            'id' => ['required', 'uuid'],
            'parent_id' => ['sometimes', 'nullable', 'uuid'],
            'name' => ['sometimes', 'string', 'filled', 'max:255'],
            'position' => ['sometimes', 'integer'],
        ]);

        $folder = $this->folder($user, (string) $data['id']) ?? new Folder;
        $this->requireOnCreate($folder, $data, 'name', 'La carpeta necesita un nombre.');
        $this->ensureFresh($folder, $operation->at);

        if (! $folder->exists) {
            $folder->id = (string) $data['id'];
            $folder->user_id = $user->id;
        }

        if (array_key_exists('parent_id', $data)) {
            $folder->parent_id = $data['parent_id'] === null ? null : $this->validParent($user, $folder, (string) $data['parent_id']);
        }

        $folder->fill(array_intersect_key($data, array_flip(['name', 'position'])));
        $this->persist($folder, $operation->at);
    }

    private function validParent(User $user, Folder $folder, string $parentId): string
    {
        $ancestor = $this->existingFolder($user, $parentId);
        $visited = [];

        while ($ancestor !== null && ! isset($visited[$ancestor->id])) {
            if ($ancestor->id === $folder->id) {
                throw new OperationRejected('Una carpeta no puede estar dentro de sí misma.');
            }

            $visited[$ancestor->id] = true;
            $ancestor = $ancestor->parent_id === null ? null : $this->folder($user, $ancestor->parent_id);
        }

        return $parentId;
    }
}
