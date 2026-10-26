<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Models\Folder;
use App\Modules\Notes\Models\Note;

final class FolderDelete extends Handler
{
    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, ['id' => ['required', 'uuid']]);
        $folder = $this->folder($user, (string) $data['id']);

        if ($folder === null) {
            return;
        }

        Folder::query()->ownedBy($user)->where('parent_id', $folder->id)->toBase()->update(['parent_id' => $folder->parent_id]);
        Note::query()->ownedBy($user)->where('folder_id', $folder->id)->toBase()->update(['folder_id' => $folder->parent_id]);
        $folder->delete();
    }
}
