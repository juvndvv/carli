<?php

namespace App\Core\Http\Controllers;

use App\Actions\Fortify\UpdateUserProfileInformation;
use App\Core\Http\Requests\UpdatePreferencesRequest;
use App\Core\Http\Requests\UpdateProfileRequest;
use App\Core\Http\Resources\MeResource;
use App\Models\User;
use Illuminate\Http\Request;

class MeController
{
    public function show(Request $request): MeResource
    {
        return new MeResource($this->user($request));
    }

    public function update(UpdateProfileRequest $request, UpdateUserProfileInformation $updater): MeResource
    {
        $user = $this->user($request);

        /** @var array<string, string> $input */
        $input = array_merge(
            ['name' => $user->name, 'email' => $user->email],
            $request->validated(),
        );

        $updater->update($user, $input);

        return new MeResource($user->refresh());
    }

    public function updatePreferences(UpdatePreferencesRequest $request): MeResource
    {
        $user = $this->user($request);

        $user->preferences = array_merge($user->preferences ?? [], $request->validated());
        $user->save();

        return new MeResource($user);
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
