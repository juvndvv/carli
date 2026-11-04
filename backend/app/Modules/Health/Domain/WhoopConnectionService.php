<?php

namespace App\Modules\Health\Domain;

use App\Models\User;
use App\Modules\Health\Models\WhoopAccount;
use App\Modules\Health\Whoop\WhoopClient;
use App\Modules\Health\Whoop\WhoopException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Links the WHOOP member: builds the consent URL, completes the callback and forgets the link.
 */
final readonly class WhoopConnectionService
{
    public const int STATE_TTL_MINUTES = 15;

    public function __construct(
        private WhoopClient $whoop,
        private WhoopSync $sync,
    ) {}

    public function authUrl(User $user): string
    {
        // Short and opaque: WHOOP only echoes it back.
        $state = Str::random(32);
        Cache::put(self::stateKey($state), $user->id, now()->addMinutes(self::STATE_TTL_MINUTES));

        return $this->whoop->authUrl($state);
    }

    /**
     * Stores (or refreshes) the link and copies the last BACKFILL_DAYS right away.
     */
    public function complete(string $state, string $code): WhoopAccount
    {
        $user = $this->userFromState($state);
        $tokens = $this->whoop->exchangeCode($code);

        if ($tokens['refresh_token'] === null) {
            throw new WhoopException('WHOOP returned no refresh token (missing offline scope).');
        }

        $profile = $this->whoop->profile($tokens['access_token']);
        $whoopUserId = $profile['user_id'] ?? null;

        if (! is_int($whoopUserId)) {
            throw new WhoopException('WHOOP returned no member id.');
        }

        if (WhoopAccount::query()->where('whoop_user_id', $whoopUserId)->where('user_id', '!=', $user->id)->exists()) {
            throw new WhoopAlreadyLinked;
        }

        $account = WhoopAccount::query()->ownedBy($user)->first() ?? new WhoopAccount(['user_id' => $user->id]);

        // Another member on the same carli user starts from scratch.
        if ($account->exists && $account->whoop_user_id !== $whoopUserId) {
            $this->forgetData($account);
            $account->synced_at = null;
        }

        $account->fill([
            'whoop_user_id' => $whoopUserId,
            'email' => is_string($profile['email'] ?? null) ? mb_strtolower($profile['email']) : null,
            'access_token' => $tokens['access_token'],
            'refresh_token' => $tokens['refresh_token'],
            'token_expires_at' => $tokens['expires_at'],
            'status' => WhoopAccount::ACTIVE,
            'last_error' => null,
        ])->save();

        if (! $this->sync->run($account)) {
            // The link is saved; the scheduled sync will try again.
            Log::warning('First WHOOP sync failed.', ['account' => $account->id, 'error' => $account->last_error]);
        }

        return $account->refresh();
    }

    /**
     * Revokes access and forgets the tokens; what was already copied stays in carli.
     */
    public function disconnect(WhoopAccount $account): void
    {
        if ($account->access_token !== null) {
            $this->whoop->revoke($account->access_token);
        }

        $account->delete();
    }

    private function forgetData(WhoopAccount $account): void
    {
        foreach (WhoopDays::MODELS as $model) {
            $model::query()->withoutGlobalScopes()->where('user_id', $account->user_id)->delete();
        }
    }

    private function userFromState(string $state): User
    {
        $userId = Cache::pull(self::stateKey($state));
        $user = is_string($userId) ? User::query()->find($userId) : null;

        if (! $user instanceof User) {
            throw new InvalidWhoopState;
        }

        return $user;
    }

    private static function stateKey(string $state): string
    {
        return 'health:whoop:state:'.hash('sha256', $state);
    }
}
