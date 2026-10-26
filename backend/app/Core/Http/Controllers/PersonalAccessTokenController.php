<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\ConfirmCurrentPasswordRequest;
use App\Core\Sessions\ActiveSessions;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Laravel\Sanctum\PersonalAccessToken;

class PersonalAccessTokenController
{
    public function index(Request $request): JsonResponse
    {
        $user = $this->user($request);
        $currentId = $this->currentTokenId($request);

        $tokens = $user->tokens()
            ->orderByRaw('last_used_at desc nulls last')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (PersonalAccessToken $token): array => [
                'id' => (int) $token->getKey(),
                'name' => $token->name,
                'last_used_at' => $token->last_used_at?->toIso8601String(),
                'created_at' => $token->created_at?->toIso8601String(),
                'is_current' => (int) $token->getKey() === $currentId,
            ])
            ->values()
            ->all();

        return response()->json(['data' => $tokens]);
    }

    public function destroy(Request $request, string $token): Response
    {
        $user = $this->user($request);

        /** @var PersonalAccessToken|null $target */
        $target = $user->tokens()->whereKey($token)->first();

        abort_if($target === null, 404);
        abort_if((int) $target->getKey() === $this->currentTokenId($request), 409, 'No puedes revocar este dispositivo desde aquí; cierra sesión.');

        $target->delete();

        return response()->noContent();
    }

    public function destroyOthers(ConfirmCurrentPasswordRequest $request, ActiveSessions $sessions): JsonResponse
    {
        $user = $this->user($request);
        $currentId = $this->currentTokenId($request);

        $revokedTokens = $user->tokens()
            ->when($currentId !== null, fn ($query) => $query->whereKeyNot($currentId))
            ->delete();

        $revokedSessions = $sessions->revokeOthers(
            $user,
            $request->hasSession() ? $request->session()->getId() : '',
        );

        return response()->json([
            'revoked_tokens' => $revokedTokens,
            'revoked_sessions' => $revokedSessions,
        ]);
    }

    private function currentTokenId(Request $request): ?int
    {
        $bearer = $request->bearerToken();
        $current = $bearer === null ? null : PersonalAccessToken::findToken($bearer);

        return $current === null ? null : (int) $current->getKey();
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
