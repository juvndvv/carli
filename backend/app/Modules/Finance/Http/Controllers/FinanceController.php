<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

abstract class FinanceController
{
    protected function user(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }

    protected function authorizeOwner(string $ability, Model $model): void
    {
        Gate::authorize($ability, $model);
    }
}
