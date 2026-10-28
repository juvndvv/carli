<?php

namespace App\Modules\Health\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

abstract class HealthController
{
    protected function user(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
