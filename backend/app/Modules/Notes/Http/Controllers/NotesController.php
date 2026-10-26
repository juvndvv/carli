<?php

namespace App\Modules\Notes\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

abstract class NotesController
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
