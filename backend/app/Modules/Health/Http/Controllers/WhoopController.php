<?php

namespace App\Modules\Health\Http\Controllers;

use App\Modules\Health\Domain\WhoopConnectionService;
use App\Modules\Health\Domain\WhoopDays;
use App\Modules\Health\Domain\WhoopSync;
use App\Modules\Health\HealthServiceProvider;
use App\Modules\Health\Models\WhoopAccount;
use App\Modules\Health\Whoop\WhoopClient;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

final class WhoopController extends HealthController
{
    public const int DEFAULT_DAYS = 14;

    public const int MAX_DAYS = 366;

    public function show(Request $request, WhoopClient $whoop): JsonResponse
    {
        $account = WhoopAccount::query()->ownedBy($this->user($request))->first();

        return response()->json(['data' => [
            'configured' => $whoop->configured(),
            'account' => $account === null ? null : self::account($account),
        ]]);
    }

    public function connect(Request $request, WhoopClient $whoop, WhoopConnectionService $connections): JsonResponse
    {
        if (! $whoop->configured()) {
            return response()->json(['message' => 'Falta configurar WHOOP en el servidor (WHOOP_CLIENT_ID y WHOOP_CLIENT_SECRET).'], 503);
        }

        return response()->json(['data' => ['auth_url' => $connections->authUrl($this->user($request))]]);
    }

    public function sync(Request $request, WhoopSync $sync): JsonResponse
    {
        $account = WhoopAccount::query()->ownedBy($this->user($request))->first();
        abort_if($account === null, 404);

        if ($account->needsReconnect() || ! $sync->run($account)) {
            $account->refresh();

            return response()->json(['message' => $account->needsReconnect()
                ? 'WHOOP ya no da acceso a tus datos. Vuelve a conectarlo.'
                : 'WHOOP no ha respondido. Se volverá a intentar en una hora.'], $account->needsReconnect() ? 409 : 502);
        }

        return response()->json(['data' => self::account($account->refresh())]);
    }

    public function destroy(Request $request, WhoopConnectionService $connections): Response
    {
        $account = WhoopAccount::query()->ownedBy($this->user($request))->first();
        abort_if($account === null, 404);
        $connections->disconnect($account);

        return response()->noContent();
    }

    public function days(Request $request, WhoopDays $days): JsonResponse
    {
        $validated = $request->validate([
            'from' => ['sometimes', 'date_format:Y-m-d'],
            'to' => ['sometimes', 'date_format:Y-m-d', 'after_or_equal:from'],
        ]);

        $to = isset($validated['to']) ? CarbonImmutable::parse($validated['to']) : CarbonImmutable::now(HealthServiceProvider::TIMEZONE)->startOfDay();
        $from = isset($validated['from']) ? CarbonImmutable::parse($validated['from']) : $to->subDays(self::DEFAULT_DAYS - 1);

        if ($from->diffInDays($to) >= self::MAX_DAYS) {
            return response()->json(['message' => 'Pide como mucho un año de datos.'], 422);
        }

        return response()->json(['data' => $days->between($this->user($request), $from, $to)]);
    }

    /**
     * @return array<string, mixed>
     */
    public static function account(WhoopAccount $account): array
    {
        return [
            'email' => $account->email,
            'status' => $account->status,
            'synced_at' => $account->synced_at?->toIso8601String(),
            'last_error' => $account->last_error === null ? null : 'La última sincronización falló; se reintentará sola.',
        ];
    }
}
