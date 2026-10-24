<?php

namespace App\Modules\Finance\Policies;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;

final class OwnedByUserPolicy
{
    public function view(User $user, Model $model): bool
    {
        return $this->owns($user, $model);
    }

    public function update(User $user, Model $model): bool
    {
        return $this->owns($user, $model);
    }

    public function delete(User $user, Model $model): bool
    {
        return $this->owns($user, $model);
    }

    private function owns(User $user, Model $model): bool
    {
        return $model->getAttribute('user_id') === $user->id;
    }
}
