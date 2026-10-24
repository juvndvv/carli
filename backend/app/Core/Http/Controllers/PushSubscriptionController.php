<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\DeletePushSubscriptionRequest;
use App\Core\Http\Requests\StorePushSubscriptionRequest;
use App\Core\Notifications\WebPushConfiguration;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class PushSubscriptionController
{
    public function publicKey(): JsonResponse
    {
        return response()->json([
            'public_key' => WebPushConfiguration::publicKey(),
            'configured' => WebPushConfiguration::isConfigured(),
        ]);
    }

    public function store(StorePushSubscriptionRequest $request): JsonResponse
    {
        $encoding = $request->validated('content_encoding');

        $subscription = $this->user($request)->updatePushSubscription(
            (string) $request->validated('endpoint'),
            (string) $request->validated('keys.p256dh'),
            (string) $request->validated('keys.auth'),
            is_string($encoding) ? $encoding : 'aes128gcm',
        );

        return response()->json([
            'data' => [
                'id' => $subscription->getKey(),
                'endpoint' => $subscription->endpoint,
            ],
        ], 201);
    }

    public function destroy(DeletePushSubscriptionRequest $request): Response
    {
        $this->user($request)->deletePushSubscription((string) $request->validated('endpoint'));

        return response()->noContent();
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
