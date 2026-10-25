<?php

namespace App\Modules\Finance\tests\Support;

use App\Models\User;
use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\Domain\Enums\BankConnectionStatus;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Http;
use OpenSSLAsymmetricKey;
use RuntimeException;

final class EnableBankingFake
{
    public const string BASE = 'https://api.enablebanking.com';

    public const string APP_ID = 'test-app-id';

    public static ?string $publicKey = null;

    private static ?string $keyPath = null;

    public static function configure(): void
    {
        if (self::$keyPath === null) {
            $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
            if (! $key instanceof OpenSSLAsymmetricKey || ! openssl_pkey_export($key, $pem)) {
                throw new RuntimeException('Could not generate a test RSA key.');
            }

            $details = openssl_pkey_get_details($key);
            self::$publicKey = is_array($details) ? $details['key'] : null;
            self::$keyPath = tempnam(sys_get_temp_dir(), 'enable-banking-').'.pem';
            file_put_contents(self::$keyPath, $pem);
        }

        config()->set('services.enable_banking', [
            'base_url' => self::BASE,
            'app_id' => self::APP_ID,
            'private_key_path' => self::$keyPath,
            'redirect_url' => null,
            'country' => 'ES',
            'jwt_ttl' => 3600,
            'timeout' => 5,
            'backoff_ms' => [1, 1],
        ]);

        app()->forgetInstance(BankDataProvider::class);
    }

    /**
     * @return array<string, mixed>
     */
    public static function aspsps(): array
    {
        return ['aspsps' => [
            ['name' => 'BBVA', 'country' => 'ES', 'logo' => 'https://logos/bbva.svg', 'maximum_consent_validity' => 90 * 86_400, 'psu_types' => ['personal']],
            ['name' => 'Revolut', 'country' => 'ES', 'logo' => null, 'maximum_consent_validity' => 180 * 86_400, 'psu_types' => ['personal', 'business']],
        ]];
    }

    /**
     * @param  list<array<string, mixed>>  $accounts
     * @return array<string, mixed>
     */
    public static function session(string $sessionId = 'session-1', array $accounts = []): array
    {
        return [
            'session_id' => $sessionId,
            'accounts' => $accounts === [] ? [self::bankAccount('uid-1', 'hash-1')] : $accounts,
            'aspsp' => ['name' => 'BBVA', 'country' => 'ES'],
            'psu_type' => 'personal',
            'access' => ['valid_until' => '2027-01-23T10:00:00.000000+00:00'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public static function bankAccount(string $uid, string $hash, string $name = 'Cuenta Online', string $type = 'CACC'): array
    {
        return [
            'uid' => $uid,
            'identification_hash' => $hash,
            'account_id' => ['iban' => 'ES9121000418450200051332'],
            'name' => $name,
            'currency' => 'EUR',
            'cash_account_type' => $type,
        ];
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    public static function transaction(string $amount, string $indicator, string $date, ?string $reference, string $counterparty = 'MERCADONA', array $overrides = []): array
    {
        return array_merge([
            'entry_reference' => $reference,
            'transaction_amount' => ['currency' => 'EUR', 'amount' => $amount],
            'creditor' => $indicator === 'DBIT' ? ['name' => $counterparty] : null,
            'debtor' => $indicator === 'CRDT' ? ['name' => $counterparty] : null,
            'credit_debit_indicator' => $indicator,
            'status' => 'BOOK',
            'booking_date' => $date,
            'value_date' => $date,
            'remittance_information' => ['COMPRA TARJETA '.$counterparty],
        ], $overrides);
    }

    /**
     * @return array<string, mixed>
     */
    public static function balances(string $amount): array
    {
        return ['balances' => [
            ['name' => 'Disponible', 'balance_amount' => ['currency' => 'EUR', 'amount' => '9999.00'], 'balance_type' => 'ITAV'],
            ['name' => 'Contable', 'balance_amount' => ['currency' => 'EUR', 'amount' => $amount], 'balance_type' => 'CLBD', 'reference_date' => '2026-10-24'],
        ]];
    }

    /**
     * @param  list<array<string, mixed>>  $transactions
     */
    public static function fakeAccountData(array $transactions, string $balance = '1000.00', string $uid = 'uid-1'): void
    {
        Http::fake([
            self::BASE."/accounts/{$uid}/transactions*" => Http::response(['transactions' => $transactions, 'continuation_key' => null]),
            self::BASE."/accounts/{$uid}/balances" => Http::response(self::balances($balance)),
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public static function connection(User $user, array $attributes = []): BankConnection
    {
        $connection = new BankConnection(array_merge([
            'aspsp_name' => 'BBVA',
            'aspsp_country' => 'ES',
            'session_id' => 'session-1',
            'valid_until' => CarbonImmutable::now()->addDays(90),
            'status' => BankConnectionStatus::Active,
            'accounts' => [[
                'uid' => 'uid-1', 'identification_hash' => 'hash-1', 'name' => 'Cuenta Online',
                'iban' => 'ES91 •••• 1332', 'currency' => 'EUR', 'type' => 'CACC',
            ]],
        ], $attributes));
        $connection->user_id = $user->id;
        $connection->save();

        return $connection;
    }

    public static function link(Account $account, BankConnection $connection, string $syncFrom, string $uid = 'uid-1'): Account
    {
        $account->forceFill([
            'bank_connection_id' => $connection->id,
            'external_account_uid' => $uid,
            'external_account_hash' => 'hash-1',
            'sync_from_date' => $syncFrom,
        ])->save();

        return $account;
    }
}
