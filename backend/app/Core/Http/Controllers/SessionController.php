<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\LogoutOtherSessionsRequest;
use App\Core\Sessions\ActiveSessions;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class SessionController
{
    public function __construct(private readonly ActiveSessions $sessions) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->sessions->for($this->user($request), $this->currentSessionId($request)),
        ]);
    }

    public function destroy(Request $request, string $session): Response
    {
        abort_unless(
            $this->sessions->revoke($this->user($request), $session, $this->currentSessionId($request)),
            404,
        );

        return response()->noContent();
    }

    public function destroyOthers(LogoutOtherSessionsRequest $request): JsonResponse
    {
        $revoked = $this->sessions->revokeOthers($this->user($request), $this->currentSessionId($request));

        return response()->json(['revoked' => $revoked]);
    }

    private function currentSessionId(Request $request): string
    {
        return $request->hasSession() ? $request->session()->getId() : '';
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
