<?php

namespace App\Modules\Calendar\Http\Controllers;

use App\Models\User;
use App\Modules\Calendar\Domain\GoogleConnectionService;
use App\Modules\Calendar\Domain\GoogleSync;
use App\Modules\Calendar\Google\GoogleClient;
use App\Modules\Calendar\Models\GoogleAccount;
use App\Modules\Calendar\Models\GoogleCalendar;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

final class GoogleAccountController
{
    public function index(Request $request, GoogleClient $google): JsonResponse
    {
        $accounts = GoogleAccount::query()->ownedBy($this->user($request))->with('calendars')->orderBy('created_at')->get();

        return response()->json(['data' => [
            'configured' => $google->configured(),
            'accounts' => $accounts->map(fn (GoogleAccount $account) => self::account($account))->values(),
        ]]);
    }

    public function connect(Request $request, GoogleClient $google, GoogleConnectionService $connections): JsonResponse
    {
        if (! $google->configured()) {
            return response()->json(['message' => 'Falta configurar Google en el servidor (GOOGLE_CLIENT_ID y GOOGLE_CLIENT_SECRET).'], 503);
        }

        return response()->json(['data' => ['auth_url' => $connections->authUrl($this->user($request))]]);
    }

    public function sync(Request $request, GoogleAccount $account, GoogleSync $sync): JsonResponse
    {
        $this->authorize($request, $account);

        if ($account->needsReconnect()) {
            return response()->json(['message' => 'Google ya no da acceso a esta cuenta. Vuelve a conectarla.'], 409);
        }

        if (! $sync->run($account)) {
            $account->refresh();

            return response()->json(['message' => $account->needsReconnect()
                ? 'Google ya no da acceso a esta cuenta. Vuelve a conectarla.'
                : 'Google no ha respondido. Se volverá a intentar en unos minutos.'], $account->needsReconnect() ? 409 : 502);
        }

        return response()->json(['data' => self::account($account->refresh()->load('calendars'))]);
    }

    public function destroy(Request $request, GoogleAccount $account, GoogleConnectionService $connections): Response
    {
        $this->authorize($request, $account);
        $connections->disconnect($account);

        return response()->noContent();
    }

    /**
     * @return array<string, mixed>
     */
    public static function account(GoogleAccount $account): array
    {
        return [
            'id' => $account->id,
            'email' => $account->email,
            'status' => $account->status,
            'synced_at' => $account->synced_at?->toIso8601String(),
            'last_error' => $account->last_error === null ? null : 'La última sincronización falló; se reintentará sola.',
            'calendars' => $account->calendars->map(fn (GoogleCalendar $calendar) => GoogleCalendarController::calendar($calendar))->values(),
        ];
    }

    private function authorize(Request $request, GoogleAccount $account): void
    {
        abort_unless($account->user_id === $this->user($request)->id, 404);
    }

    private function user(Request $request): User
    {
        $user = $request->user();
        abort_unless($user instanceof User, 401);

        return $user;
    }
}
