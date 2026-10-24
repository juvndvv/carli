<?php

namespace App\Core\Sessions;

use App\Models\User;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class ActiveSessions
{
    /**
     * @return list<array{id: string, device: string, browser: string|null, platform: string|null, is_mobile: bool, ip_address: string|null, last_active_at: string, is_current: bool}>
     */
    public function for(User $user, string $currentSessionId): array
    {
        return array_values($this->query($user)
            ->orderByDesc('last_activity')
            ->get(['id', 'ip_address', 'user_agent', 'last_activity'])
            ->map(function (object $session) use ($currentSessionId): array {
                $agent = new UserAgent(is_string($session->user_agent ?? null) ? $session->user_agent : null);

                return [
                    'id' => self::publicId((string) $session->id),
                    'device' => $agent->label(),
                    'browser' => $agent->browser(),
                    'platform' => $agent->platform(),
                    'is_mobile' => $agent->isMobile(),
                    'ip_address' => is_string($session->ip_address ?? null) ? $session->ip_address : null,
                    'last_active_at' => Carbon::createFromTimestamp((int) $session->last_activity)->toIso8601String(),
                    'is_current' => hash_equals((string) $session->id, $currentSessionId),
                ];
            })
            ->all());
    }

    public function revoke(User $user, string $publicId, string $currentSessionId): bool
    {
        $target = $this->query($user)
            ->pluck('id')
            ->map(fn (mixed $id) => (string) $id)
            ->first(fn (string $id) => hash_equals(self::publicId($id), $publicId) && $id !== $currentSessionId);

        if ($target === null) {
            return false;
        }

        return $this->query($user)->where('id', $target)->delete() > 0;
    }

    public function revokeOthers(User $user, string $currentSessionId): int
    {
        $user->setRememberToken(Str::random(60));
        $user->save();

        return $this->query($user)->where('id', '!=', $currentSessionId)->delete();
    }

    public static function publicId(string $sessionId): string
    {
        return hash_hmac('sha256', $sessionId, (string) config('app.key'));
    }

    private function query(User $user): Builder
    {
        return $this->connection()
            ->table((string) config('session.table', 'sessions'))
            ->where('user_id', $user->id);
    }

    private function connection(): ConnectionInterface
    {
        $connection = config('session.connection');

        return DB::connection(is_string($connection) ? $connection : null);
    }
}
