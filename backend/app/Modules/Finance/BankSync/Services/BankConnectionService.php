<?php

namespace App\Modules\Finance\BankSync\Services;

use App\Models\User;
use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Data\Aspsp;
use App\Modules\Finance\BankSync\Data\BankAccount;
use App\Modules\Finance\BankSync\Data\BankSession;
use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use App\Modules\Finance\BankSync\Exceptions\InvalidBankState;
use App\Modules\Finance\Domain\Enums\BankConnectionStatus;
use App\Modules\Finance\Domain\Services\AccountService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Jobs\SyncBankConnection;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class BankConnectionService
{
    public const int STATE_TTL_MINUTES = 30;

    private const int ASPSP_CACHE_SECONDS = 21_600;

    public function __construct(
        private readonly BankDataProvider $provider,
        private readonly AccountService $accounts,
    ) {}

    /**
     * @return list<Aspsp>
     */
    public function aspsps(string $country): array
    {
        $country = strtoupper($country);

        /** @var list<array{name: string, country: string, logo: string|null, maximum_consent_validity: int|null}> $cached */
        $cached = Cache::remember(
            "finance:bank:aspsps:{$this->provider->id()}:{$country}",
            self::ASPSP_CACHE_SECONDS,
            fn () => array_map(fn (Aspsp $aspsp) => [
                'name' => $aspsp->name,
                'country' => $aspsp->country,
                'logo' => $aspsp->logo,
                'maximum_consent_validity' => $aspsp->maximumConsentValiditySeconds,
            ], $this->provider->listAspsps($country)),
        );

        return array_map(fn (array $item) => new Aspsp($item['name'], $item['country'], $item['logo'], $item['maximum_consent_validity']), $cached);
    }

    public function start(User $user, string $aspspName, string $country): string
    {
        return $this->authorize($user, $this->aspsp($aspspName, $country), null);
    }

    public function renew(BankConnection $connection): string
    {
        $user = User::query()->findOrFail($connection->user_id);

        return $this->authorize($user, $this->aspsp($connection->aspsp_name, $connection->aspsp_country), $connection->id);
    }

    /**
     * @return array{connection: BankConnection, renewed: bool}
     */
    public function complete(string $state, string $code): array
    {
        $payload = $this->decodeState($state);
        $user = User::query()->find($payload['user_id']);

        if ($user === null) {
            throw new InvalidBankState;
        }

        $session = $this->provider->completeAuth($code);

        if ($payload['connection_id'] !== null) {
            $connection = BankConnection::query()->ownedBy($user)->whereKey($payload['connection_id'])->first();

            if ($connection !== null && $connection->status !== BankConnectionStatus::Revoked) {
                return ['connection' => $this->applyRenewal($connection, $session), 'renewed' => true];
            }
        }

        $connection = new BankConnection;
        $connection->user_id = $user->id;
        $connection->provider = $this->provider->id();
        $connection->aspsp_name = $payload['aspsp_name'];
        $connection->aspsp_country = $payload['aspsp_country'];
        $connection->session_id = $session->sessionId;
        $connection->valid_until = $session->validUntil;
        $connection->status = BankConnectionStatus::Active;
        $connection->accounts = array_map(fn (BankAccount $account) => $account->toArray(), $session->accounts);
        $connection->save();

        return ['connection' => $connection, 'renewed' => false];
    }

    /**
     * @param  list<array{external_account_uid: string, account_id: string|null, name?: string|null, type?: string|null, sync_from_date?: string|null}>  $items
     */
    public function link(BankConnection $connection, array $items): BankConnection
    {
        if ($connection->status === BankConnectionStatus::Revoked) {
            throw ValidationException::withMessages(['connection' => 'Esta conexión está desconectada.']);
        }

        $user = User::query()->findOrFail($connection->user_id);
        $errors = [];

        foreach ($items as $index => $item) {
            if ($connection->bankAccount($item['external_account_uid']) === null) {
                $errors["accounts.$index.external_account_uid"] = 'La cuenta no pertenece a esta conexión.';
            }
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        $linked = DB::transaction(function () use ($connection, $user, $items): bool {
            $linked = false;

            foreach ($items as $index => $item) {
                $uid = $item['external_account_uid'];
                $snapshot = $connection->bankAccount($uid);
                if ($snapshot === null) {
                    continue;
                }
                $bankAccount = BankAccount::fromArray($snapshot);

                if ($item['account_id'] === null) {
                    $this->unlink(Account::query()->ownedBy($user)->where('bank_connection_id', $connection->id)->where('external_account_uid', $uid)->get());

                    continue;
                }

                $account = $item['account_id'] === 'new'
                    ? $this->accounts->create($user, [
                        'name' => $item['name'] ?? $bankAccount->name ?? $connection->aspsp_name,
                        'type' => $item['type'] ?? $bankAccount->suggestedAccountType()->value,
                    ])
                    : Account::query()->ownedBy($user)->whereKey($item['account_id'])->first();

                if ($account === null || $account->isArchived()) {
                    throw ValidationException::withMessages(["accounts.$index.account_id" => 'La cuenta no existe.']);
                }

                if ($this->linkedElsewhere($account, $connection)) {
                    throw ValidationException::withMessages(["accounts.$index.account_id" => 'Esta cuenta ya está vinculada a otra cuenta del banco.']);
                }

                $this->unlink(Account::query()->ownedBy($user)
                    ->where('bank_connection_id', $connection->id)
                    ->where('external_account_uid', $uid)
                    ->whereKeyNot($account->id)
                    ->get());

                $account->forceFill([
                    'bank_connection_id' => $connection->id,
                    'external_account_uid' => $uid,
                    'external_account_hash' => $bankAccount->identificationHash,
                    'sync_from_date' => isset($item['sync_from_date']) ? SpanishCalendar::date($item['sync_from_date']) : ($account->sync_from_date ?? SpanishCalendar::today()),
                ])->save();

                $linked = true;
            }

            return $linked;
        });

        if ($linked && $connection->status->isSyncable()) {
            SyncBankConnection::dispatch($connection->id);
        }

        return $connection->refresh();
    }

    public function revoke(BankConnection $connection): void
    {
        if ($connection->session_id !== null && $connection->status !== BankConnectionStatus::Revoked) {
            try {
                $this->provider->revoke($connection->session_id);
            } catch (BankProviderException $exception) {
                if (! $exception->isSessionInvalid()) {
                    throw $exception;
                }
            }
        }

        DB::transaction(function () use ($connection): void {
            $this->unlink(Account::query()->ownedBy($connection->user_id)->where('bank_connection_id', $connection->id)->get());

            $connection->forceFill([
                'status' => BankConnectionStatus::Revoked,
                'session_id' => null,
                'last_error' => null,
            ])->save();
        });
    }

    public function redirectUrl(): string
    {
        $configured = config('services.enable_banking.redirect_url');

        return is_string($configured) && $configured !== '' ? $configured : route('finance.bank.callback');
    }

    public function encodeState(string $userId, string $aspspName, string $country, ?string $connectionId): string
    {
        return Crypt::encryptString((string) json_encode([
            'u' => $userId,
            'c' => $connectionId,
            'a' => $aspspName,
            'k' => $country,
            'n' => Str::random(32),
            'x' => CarbonImmutable::now()->addMinutes(self::STATE_TTL_MINUTES)->getTimestamp(),
        ]));
    }

    /**
     * @return array{user_id: string, connection_id: string|null, aspsp_name: string, aspsp_country: string}
     */
    public function decodeState(string $state): array
    {
        try {
            $payload = json_decode(Crypt::decryptString($state), true);
        } catch (DecryptException) {
            throw new InvalidBankState;
        }

        if (! is_array($payload)
            || ! is_string($payload['u'] ?? null)
            || ! is_string($payload['a'] ?? null)
            || ! is_string($payload['k'] ?? null)
            || ! is_string($payload['n'] ?? null)
            || ! is_int($payload['x'] ?? null)
            || $payload['x'] < CarbonImmutable::now()->getTimestamp()
            || ! Cache::add('finance:bank:state:'.$payload['n'], true, now()->addMinutes(self::STATE_TTL_MINUTES + 5))) {
            throw new InvalidBankState;
        }

        return [
            'user_id' => $payload['u'],
            'connection_id' => is_string($payload['c'] ?? null) ? $payload['c'] : null,
            'aspsp_name' => $payload['a'],
            'aspsp_country' => $payload['k'],
        ];
    }

    private function authorize(User $user, Aspsp $aspsp, ?string $connectionId): string
    {
        $state = $this->encodeState($user->id, $aspsp->name, $aspsp->country, $connectionId);
        $validUntil = CarbonImmutable::now()->addDays($aspsp->consentDays());

        return $this->provider->startAuth($aspsp, $this->redirectUrl(), $state, $validUntil);
    }

    private function aspsp(string $name, string $country): Aspsp
    {
        foreach ($this->aspsps($country) as $aspsp) {
            if (strcasecmp($aspsp->name, $name) === 0 && strcasecmp($aspsp->country, $country) === 0) {
                return $aspsp;
            }
        }

        throw ValidationException::withMessages(['aspsp_name' => 'Ese banco no está disponible.']);
    }

    private function applyRenewal(BankConnection $connection, BankSession $session): BankConnection
    {
        $previousSession = $connection->session_id;

        DB::transaction(function () use ($connection, $session): void {
            $byHash = [];
            $uids = [];
            foreach ($session->accounts as $account) {
                $uids[$account->uid] = true;
                if ($account->identificationHash !== null) {
                    $byHash[$account->identificationHash] = $account->uid;
                }
            }

            $linked = Account::query()->ownedBy($connection->user_id)->where('bank_connection_id', $connection->id)->get();
            $previousUids = $linked->mapWithKeys(fn (Account $account) => [$account->id => $account->external_account_uid])->all();
            $linked->each(fn (Account $account) => $account->forceFill(['external_account_uid' => null])->save());

            foreach ($linked as $account) {
                $previousUid = $previousUids[$account->id] ?? null;
                $uid = ($account->external_account_hash !== null ? ($byHash[$account->external_account_hash] ?? null) : null)
                    ?? ($previousUid !== null && isset($uids[$previousUid]) ? $previousUid : null);

                $account->forceFill(['external_account_uid' => $uid])->save();
            }

            $connection->forceFill([
                'session_id' => $session->sessionId,
                'valid_until' => $session->validUntil,
                'status' => BankConnectionStatus::Active,
                'accounts' => array_map(fn (BankAccount $account) => $account->toArray(), $session->accounts),
                'expiry_notice_days' => null,
                'last_error' => null,
            ])->save();
        });

        if ($previousSession !== null && $previousSession !== $session->sessionId) {
            try {
                $this->provider->revoke($previousSession);
            } catch (BankProviderException $exception) {
                Log::warning('Could not revoke the previous bank session after renewal.', ['connection' => $connection->id, 'error' => $exception->getMessage()]);
            }
        }

        return $connection->refresh();
    }

    private function linkedElsewhere(Account $account, BankConnection $connection): bool
    {
        if ($account->bank_connection_id === null || $account->external_account_uid === null) {
            return false;
        }

        if ($account->bank_connection_id === $connection->id) {
            return false;
        }

        return BankConnection::query()->ownedBy($connection->user_id)
            ->whereKey($account->bank_connection_id)
            ->where('status', '<>', BankConnectionStatus::Revoked->value)
            ->exists();
    }

    /**
     * @param  iterable<Account>  $accounts
     */
    private function unlink(iterable $accounts): void
    {
        foreach ($accounts as $account) {
            $account->forceFill([
                'bank_connection_id' => null,
                'external_account_uid' => null,
                'external_account_hash' => null,
                'sync_from_date' => null,
                'bank_balance_cents' => null,
                'bank_balance_at' => null,
            ])->save();
        }
    }
}
