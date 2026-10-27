<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\UpdateNotificationPreferencesRequest;
use App\Core\Notifications\NotificationPreferenceService;
use App\Core\Push\ApnsConfiguration;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationPreferenceController
{
    public function __construct(private readonly NotificationPreferenceService $preferences) {}

    public function index(Request $request): JsonResponse
    {
        return $this->respond($this->user($request));
    }

    public function update(UpdateNotificationPreferencesRequest $request): JsonResponse
    {
        $user = $this->user($request);

        $this->preferences->update($user, $request->preferences());

        return $this->respond($user);
    }

    private function respond(User $user): JsonResponse
    {
        return response()->json([
            'data' => $this->preferences->grouped($user),
            'push_configured' => ApnsConfiguration::isConfigured(),
        ]);
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
