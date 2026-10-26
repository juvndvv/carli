<?php

namespace App\Core\Http\Controllers;

use App\Actions\Fortify\UpdateUserPassword;
use App\Core\Http\Requests\UpdatePasswordRequest;
use App\Models\User;
use Illuminate\Http\Response;

class PasswordController
{
    public function update(UpdatePasswordRequest $request, UpdateUserPassword $updater): Response
    {
        /** @var User $user */
        $user = $request->user();

        /** @var array<string, string> $input */
        $input = $request->only(['current_password', 'password', 'password_confirmation']);

        $updater->update($user, $input);

        return response()->noContent();
    }
}
