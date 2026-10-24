<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\MarkNotificationsReadRequest;
use App\Core\Http\Resources\NotificationResource;
use App\Core\Notifications\TestNotification;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class NotificationController
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $this->user($request);

        $perPage = min(max($request->integer('per_page', 20), 1), 100);

        $notifications = $user->notifications()
            ->when($request->boolean('unread'), fn ($query) => $query->whereNull('read_at'))
            ->paginate($perPage);

        return NotificationResource::collection($notifications)
            ->additional(['meta' => ['unread_count' => $user->unreadNotifications()->count()]]);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        return response()->json(['unread_count' => $this->user($request)->unreadNotifications()->count()]);
    }

    public function markRead(MarkNotificationsReadRequest $request): JsonResponse
    {
        $user = $this->user($request);

        $query = $user->unreadNotifications();

        if (! $request->boolean('all')) {
            $query->whereIn('id', (array) $request->validated('ids', []));
        }

        $marked = $query->update(['read_at' => now()]);

        return response()->json([
            'marked' => $marked,
            'unread_count' => $user->unreadNotifications()->count(),
        ]);
    }

    public function test(Request $request): JsonResponse
    {
        $user = $this->user($request);
        $notification = new TestNotification;

        $user->notify($notification);

        return response()->json(['channels' => $notification->via($user)], 202);
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
