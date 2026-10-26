<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Sync\Operation;

final class ItemDelete extends Handler
{
    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, ['id' => ['required', 'uuid']]);

        $this->item($user, (string) $data['id'])?->delete();
    }
}
