<?php

namespace App\Modules\Calendar\Domain;

use App\Models\User;
use App\Modules\Calendar\Google\GoogleClient;
use App\Modules\Calendar\Google\GoogleException;
use App\Modules\Calendar\Models\GoogleAccount;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Links Google accounts: builds the consent URL, completes the callback and forgets accounts.
 */
final readonly class GoogleConnectionService
{
    public const int STATE_TTL_MINUTES = 15;

    public function __construct(
        private GoogleClient $google,
        private GoogleSync $sync,
    ) {}

    public function authUrl(User $user): string
    {
        $state = Crypt::encryptString((string) json_encode([
            'u' => $user->id,
            'n' => Str::random(32),
            'x' => CarbonImmutable::now()->addMinutes(self::STATE_TTL_MINUTES)->getTimestamp(),
        ]));

        return $this->google->authUrl($state);
    }

    /**
     * Stores (or refreshes) the account behind the code and copies its calendars right away.
     */
    public function complete(string $state, string $code): GoogleAccount
    {
        $user = $this->userFromState($state);
        $tokens = $this->google->exchangeCode($code);

        if (! in_array(GoogleClient::SCOPE, explode(' ', $tokens['scope']), true)) {
            throw new MissingCalendarScope;
        }

        $calendars = $this->google->calendars($tokens['access_token']);
        $primary = collect($calendars)->first(fn (array $calendar) => ($calendar['primary'] ?? false) === true);
        $email = is_array($primary) && is_string($primary['id'] ?? null) ? $primary['id'] : null;

        if ($email === null) {
            throw new GoogleException('Google returned no primary calendar for the account.');
        }

        $account = GoogleAccount::query()->ownedBy($user)->firstOrNew(['email' => mb_strtolower($email)], ['user_id' => $user->id]);
        $refresh = $tokens['refresh_token'] ?? ($account->exists ? $account->refresh_token : null);

        if ($refresh === null) {
            throw new GoogleException('Google returned no refresh token.');
        }

        $account->fill([
            'user_id' => $user->id,
            'access_token' => $tokens['access_token'],
            'refresh_token' => $refresh,
            'token_expires_at' => $tokens['expires_at'],
            'status' => GoogleAccount::ACTIVE,
            'last_error' => null,
        ])->save();

        try {
            $this->sync->account($account, $calendars);
        } catch (GoogleException $exception) {
            // The link is saved; the scheduled sync will try again.
            Log::warning('First Google Calendar sync failed.', ['account' => $account->id, 'error' => $exception->getMessage()]);
        }

        return $account->refresh();
    }

    public function disconnect(GoogleAccount $account): void
    {
        $this->google->revoke($account->refresh_token);
        $account->delete();
    }

    private function userFromState(string $state): User
    {
        try {
            $payload = json_decode(Crypt::decryptString($state), true);
        } catch (DecryptException) {
            throw new InvalidGoogleState;
        }

        if (! is_array($payload)
            || ! is_string($payload['u'] ?? null)
            || ! is_string($payload['n'] ?? null)
            || ! is_int($payload['x'] ?? null)
            || $payload['x'] < CarbonImmutable::now()->getTimestamp()
            || ! Cache::add('calendar:google:state:'.$payload['n'], true, now()->addMinutes(self::STATE_TTL_MINUTES + 5))) {
            throw new InvalidGoogleState;
        }

        $user = User::query()->find($payload['u']);

        if (! $user instanceof User) {
            throw new InvalidGoogleState;
        }

        return $user;
    }
}
