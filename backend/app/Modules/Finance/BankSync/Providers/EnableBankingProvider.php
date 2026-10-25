<?php

namespace App\Modules\Finance\BankSync\Providers;

use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Data\Aspsp;
use App\Modules\Finance\BankSync\Data\BankAccount;
use App\Modules\Finance\BankSync\Data\BankAmount;
use App\Modules\Finance\BankSync\Data\BankBalance;
use App\Modules\Finance\BankSync\Data\BankSession;
use App\Modules\Finance\BankSync\Data\PsuContext;
use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use App\Modules\Finance\BankSync\Exceptions\BankProviderNotConfigured;
use Carbon\CarbonImmutable;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Throwable;

final class EnableBankingProvider implements BankDataProvider
{
    public const string ID = 'enable_banking';

    private const int MAX_PAGES = 100;

    private const array BALANCE_PREFERENCE = ['CLBD', 'ITBD', 'XPCD', 'ITAV', 'CLAV', 'OPBD', 'PRCD', 'OTHR'];

    private ?string $token = null;

    private int $tokenExpiresAt = 0;

    /**
     * @param  list<int>  $backoffMilliseconds
     */
    public function __construct(
        private readonly string $baseUrl,
        private readonly ?string $applicationId,
        private readonly ?string $privateKeyPath,
        private readonly int $tokenTtlSeconds = 3600,
        private readonly int $timeoutSeconds = 30,
        private readonly array $backoffMilliseconds = [500, 2000, 5000],
    ) {}

    /**
     * @param  array<string, mixed>  $config
     */
    public static function fromConfig(array $config): self
    {
        $backoff = $config['backoff_ms'] ?? [500, 2000, 5000];

        return new self(
            baseUrl: rtrim(is_string($config['base_url'] ?? null) ? $config['base_url'] : 'https://api.enablebanking.com', '/'),
            applicationId: is_string($config['app_id'] ?? null) && $config['app_id'] !== '' ? $config['app_id'] : null,
            privateKeyPath: is_string($config['private_key_path'] ?? null) && $config['private_key_path'] !== '' ? $config['private_key_path'] : null,
            tokenTtlSeconds: (int) ($config['jwt_ttl'] ?? 3600),
            timeoutSeconds: (int) ($config['timeout'] ?? 30),
            backoffMilliseconds: is_array($backoff) ? array_values(array_map('intval', $backoff)) : [500, 2000, 5000],
        );
    }

    public function id(): string
    {
        return self::ID;
    }

    public function listAspsps(string $country): array
    {
        $body = $this->json(fn () => $this->request()->get('/aspsps', ['country' => strtoupper($country), 'psu_type' => 'personal']), 'listar los bancos');
        $aspsps = [];

        foreach ($this->list($body['aspsps'] ?? []) as $item) {
            if (! is_string($item['name'] ?? null) || ! is_string($item['country'] ?? null)) {
                continue;
            }

            $aspsps[] = new Aspsp(
                name: $item['name'],
                country: $item['country'],
                logo: is_string($item['logo'] ?? null) ? $item['logo'] : null,
                maximumConsentValiditySeconds: is_numeric($item['maximum_consent_validity'] ?? null) ? (int) $item['maximum_consent_validity'] : null,
                psuTypes: array_values(array_filter((array) ($item['psu_types'] ?? []), 'is_string')),
            );
        }

        return $aspsps;
    }

    public function startAuth(Aspsp $aspsp, string $redirectUrl, string $state, CarbonImmutable $validUntil): string
    {
        $body = $this->json(fn () => $this->request()->post('/auth', [
            'access' => ['valid_until' => $validUntil->utc()->format('Y-m-d\TH:i:s.v\Z')],
            'aspsp' => ['name' => $aspsp->name, 'country' => $aspsp->country],
            'state' => $state,
            'redirect_url' => $redirectUrl,
            'psu_type' => 'personal',
        ]), 'iniciar la autorización');

        if (! is_string($body['url'] ?? null)) {
            throw new BankProviderException('El proveedor no devolvió la URL de autorización.');
        }

        return $body['url'];
    }

    public function completeAuth(string $code): BankSession
    {
        $body = $this->json(fn () => $this->request()->post('/sessions', ['code' => $code]), 'crear la sesión');

        if (! is_string($body['session_id'] ?? null)) {
            throw new BankProviderException('El proveedor no devolvió la sesión.');
        }

        $access = is_array($body['access'] ?? null) ? $body['access'] : [];

        return new BankSession(
            sessionId: $body['session_id'],
            validUntil: $this->date($access['valid_until'] ?? null) ?? CarbonImmutable::now()->addDays(Aspsp::DEFAULT_CONSENT_DAYS),
            accounts: array_values(array_filter(array_map(fn (array $account) => $this->account($account), $this->list($body['accounts'] ?? [])))),
        );
    }

    public function listAccounts(string $sessionId): array
    {
        $body = $this->json(fn () => $this->request()->get('/sessions/'.rawurlencode($sessionId)), 'consultar la sesión');
        $hashes = [];

        foreach ($this->list($body['accounts_data'] ?? []) as $data) {
            if (is_string($data['uid'] ?? null)) {
                $hashes[$data['uid']] = is_string($data['identification_hash'] ?? null) ? $data['identification_hash'] : null;
            }
        }

        $accounts = [];
        foreach ((array) ($body['accounts'] ?? []) as $uid) {
            if (! is_string($uid)) {
                continue;
            }

            $details = $this->json(fn () => $this->request()->get('/accounts/'.rawurlencode($uid).'/details'), 'consultar la cuenta');
            $account = $this->account([...$details, 'uid' => $uid, 'identification_hash' => $hashes[$uid] ?? ($details['identification_hash'] ?? null)]);

            if ($account !== null) {
                $accounts[] = $account;
            }
        }

        return $accounts;
    }

    public function fetchTransactions(string $accountUid, CarbonImmutable $from, CarbonImmutable $to, ?PsuContext $psu = null): array
    {
        $transactions = [];
        $continuationKey = null;
        $pages = 0;

        do {
            $query = array_filter([
                'date_from' => $from->toDateString(),
                'date_to' => $to->toDateString(),
                'continuation_key' => $continuationKey,
            ], fn (?string $value) => $value !== null);

            $body = $this->json(
                fn () => $this->request($psu)->get('/accounts/'.rawurlencode($accountUid).'/transactions', $query),
                'descargar los movimientos',
            );

            foreach ($this->list($body['transactions'] ?? []) as $transaction) {
                $transactions[] = $transaction;
            }

            $next = $body['continuation_key'] ?? null;
            $continuationKey = is_string($next) && $next !== '' && $next !== $continuationKey ? $next : null;
            $pages++;
        } while ($continuationKey !== null && $pages < self::MAX_PAGES);

        return $transactions;
    }

    public function fetchBalance(string $accountUid, ?PsuContext $psu = null): ?BankBalance
    {
        $body = $this->json(fn () => $this->request($psu)->get('/accounts/'.rawurlencode($accountUid).'/balances'), 'consultar el saldo');
        $balances = [];

        foreach ($this->list($body['balances'] ?? []) as $balance) {
            $amount = is_array($balance['balance_amount'] ?? null) ? ($balance['balance_amount']['amount'] ?? null) : null;
            if (! is_string($amount) && ! is_numeric($amount)) {
                continue;
            }

            $type = is_string($balance['balance_type'] ?? null) ? $balance['balance_type'] : 'OTHR';
            $balances[$type] ??= new BankBalance(
                amountCents: BankAmount::toCents(is_string($amount) ? $amount : (float) $amount),
                type: $type,
                referenceDate: $this->date($balance['reference_date'] ?? null),
            );
        }

        foreach (self::BALANCE_PREFERENCE as $type) {
            if (isset($balances[$type])) {
                return $balances[$type];
            }
        }

        return $balances === [] ? null : reset($balances);
    }

    public function revoke(string $sessionId): void
    {
        $response = $this->send(fn () => $this->request()->delete('/sessions/'.rawurlencode($sessionId)));

        if ($response->failed() && $response->status() !== 404) {
            throw $this->failure($response, 'revocar el consentimiento');
        }
    }

    public function jwt(): string
    {
        $now = time();

        if ($this->token !== null && $this->tokenExpiresAt - 60 > $now) {
            return $this->token;
        }

        if ($this->applicationId === null || $this->privateKeyPath === null) {
            throw new BankProviderNotConfigured('Falta ENABLE_BANKING_APP_ID o la clave privada de Enable Banking.');
        }

        $pem = is_readable($this->privateKeyPath) ? file_get_contents($this->privateKeyPath) : false;
        $key = $pem === false ? false : openssl_pkey_get_private($pem);

        if ($key === false) {
            throw new BankProviderNotConfigured("No se puede leer la clave privada de Enable Banking en {$this->privateKeyPath}.");
        }

        $ttl = max(60, min(86_400, $this->tokenTtlSeconds));
        $segments = [
            self::base64Url((string) json_encode(['typ' => 'JWT', 'alg' => 'RS256', 'kid' => $this->applicationId])),
            self::base64Url((string) json_encode(['iss' => 'enablebanking.com', 'aud' => 'api.enablebanking.com', 'iat' => $now, 'exp' => $now + $ttl])),
        ];

        if (! openssl_sign(implode('.', $segments), $signature, $key, OPENSSL_ALGO_SHA256)) {
            throw new BankProviderNotConfigured('No se pudo firmar el token de Enable Banking.');
        }

        $this->token = implode('.', [...$segments, self::base64Url($signature)]);
        $this->tokenExpiresAt = $now + $ttl;

        return $this->token;
    }

    public static function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function request(?PsuContext $psu = null): PendingRequest
    {
        return Http::baseUrl($this->baseUrl)
            ->withToken($this->jwt())
            ->withHeaders($psu?->headers() ?? [])
            ->acceptJson()
            ->asJson()
            ->timeout($this->timeoutSeconds)
            ->retry(
                $this->backoffMilliseconds === [] ? 1 : $this->backoffMilliseconds,
                when: fn (Throwable $exception) => $exception instanceof ConnectionException
                    || ($exception instanceof RequestException && ($exception->response->status() === 429 || $exception->response->serverError())),
                throw: false,
            );
    }

    /**
     * @param  callable(): Response  $call
     */
    private function send(callable $call): Response
    {
        try {
            return $call();
        } catch (ConnectionException $exception) {
            throw new BankProviderException('No se pudo conectar con el proveedor bancario.', null, $exception);
        }
    }

    /**
     * @param  callable(): Response  $call
     * @return array<string, mixed>
     */
    private function json(callable $call, string $action): array
    {
        $response = $this->send($call);

        if ($response->failed()) {
            throw $this->failure($response, $action);
        }

        $body = $response->json();

        return is_array($body) ? $body : [];
    }

    private function failure(Response $response, string $action): BankProviderException
    {
        $body = $response->json();
        $detail = is_array($body) ? ($body['message'] ?? $body['error'] ?? null) : null;

        return new BankProviderException(
            "Error del proveedor bancario al {$action} (HTTP {$response->status()})".(is_string($detail) && $detail !== '' ? ": {$detail}" : '.'),
            $response->status(),
        );
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function list(mixed $value): array
    {
        return is_array($value) ? array_values(array_filter($value, 'is_array')) : [];
    }

    /**
     * @param  array<string, mixed>  $account
     */
    private function account(array $account): ?BankAccount
    {
        if (! is_string($account['uid'] ?? null)) {
            return null;
        }

        $identification = is_array($account['account_id'] ?? null) ? $account['account_id'] : [];
        $iban = is_string($identification['iban'] ?? null) ? $identification['iban'] : null;
        $name = collect([$account['name'] ?? null, $account['product'] ?? null, $account['details'] ?? null])
            ->first(fn (mixed $value) => is_string($value) && $value !== '');

        return new BankAccount(
            uid: $account['uid'],
            identificationHash: is_string($account['identification_hash'] ?? null) ? $account['identification_hash'] : null,
            name: is_string($name) ? $name : null,
            iban: BankAccount::maskIban($iban),
            currency: is_string($account['currency'] ?? null) ? $account['currency'] : null,
            type: is_string($account['cash_account_type'] ?? null) ? $account['cash_account_type'] : null,
        );
    }

    private function date(mixed $value): ?CarbonImmutable
    {
        if (! is_string($value) || $value === '') {
            return null;
        }

        try {
            return CarbonImmutable::parse($value);
        } catch (Throwable) {
            return null;
        }
    }
}
