<?php

namespace App\Modules\Notes\Domain\Sync;

use App\Models\User;

interface OperationHandler
{
    public function handle(User $user, Operation $operation): void;
}
