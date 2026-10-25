<?php

use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Data\Aspsp;
use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use App\Modules\Finance\BankSync\Exceptions\BankProviderNotConfigured;
use App\Modules\Finance\BankSync\Providers\EnableBankingProvider;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

function decodeSegment(string $segment): array
{
    return json_decode(base64_decode(strtr($segment, '-_', '+/')), true);
}

beforeEach(function () {
    EB::configure();
    $this->provider = app(BankDataProvider::class);
});

it('is bound to the Enable Banking provider', function () {
    expect($this->provider)->toBeInstanceOf(EnableBankingProvider::class)
        ->and($this->provider->id())->toBe('enable_banking');
});

it('signs an RS256 JWT with the application key', function () {
    $token = $this->provider->jwt();
    [$header, $payload, $signature] = explode('.', $token);

    $claims = decodeSegment($payload);
    $verified = openssl_verify("{$header}.{$payload}", base64_decode(strtr($signature, '-_', '+/')), (string) EB::$publicKey, OPENSSL_ALGO_SHA256);

    expect(decodeSegment($header))->toBe(['typ' => 'JWT', 'alg' => 'RS256', 'kid' => EB::APP_ID])
        ->and($claims['iss'])->toBe('enablebanking.com')
        ->and($claims['aud'])->toBe('api.enablebanking.com')
        ->and($claims['exp'] - $claims['iat'])->toBe(3600)
        ->and($verified)->toBe(1)
        ->and($this->provider->jwt())->toBe($token);
});

it('caps the token lifetime at 24 hours', function () {
    config()->set('services.enable_banking.jwt_ttl', 7 * 86_400);
    app()->forgetInstance(BankDataProvider::class);

    $claims = decodeSegment(explode('.', app(BankDataProvider::class)->jwt())[1]);

    expect($claims['exp'] - $claims['iat'])->toBe(86_400);
});

it('fails clearly when the key is missing', function () {
    config()->set('services.enable_banking.private_key_path', '/nonexistent/enable_banking.pem');
    app()->forgetInstance(BankDataProvider::class);

    app(BankDataProvider::class)->listAspsps('ES');
})->throws(BankProviderNotConfigured::class);

it('sends the bearer token and parses banks', function () {
    Http::fake([EB::BASE.'/aspsps*' => Http::response(EB::aspsps())]);

    $aspsps = $this->provider->listAspsps('es');

    expect($aspsps)->toHaveCount(2)
        ->and($aspsps[0]->name)->toBe('BBVA')
        ->and($aspsps[0]->consentDays())->toBe(90)
        ->and($aspsps[1]->consentDays())->toBe(180);

    Http::assertSent(fn (Request $request) => str_starts_with($request->url(), EB::BASE.'/aspsps?')
        && $request['country'] === 'ES'
        && str_starts_with($request->header('Authorization')[0], 'Bearer '));
});

it('follows continuation keys when downloading transactions', function () {
    Http::fake([
        EB::BASE.'/accounts/uid-1/transactions*' => Http::sequence()
            ->push(['transactions' => [EB::transaction('1.00', 'DBIT', '2026-10-20', 'a')], 'continuation_key' => 'next-page'])
            ->push(['transactions' => [EB::transaction('2.00', 'DBIT', '2026-10-21', 'b')], 'continuation_key' => null]),
    ]);

    $rows = $this->provider->fetchTransactions('uid-1', SpanishCalendar::date('2026-10-01'), SpanishCalendar::date('2026-10-24'));

    expect(array_column($rows, 'entry_reference'))->toBe(['a', 'b']);
    Http::assertSentCount(2);
    Http::assertSent(fn (Request $request) => ($request->data()['continuation_key'] ?? null) === 'next-page'
        && $request['date_from'] === '2026-10-01'
        && $request['date_to'] === '2026-10-24');
});

it('retries server errors with backoff before failing', function () {
    Http::fake([
        EB::BASE.'/accounts/uid-1/balances' => Http::sequence()
            ->push(['error' => 'busy'], 503)
            ->push(EB::balances('1234.56')),
    ]);

    $balance = $this->provider->fetchBalance('uid-1');

    expect($balance?->amountCents)->toBe(123456)
        ->and($balance?->type)->toBe('CLBD');
    Http::assertSentCount(2);
});

it('raises a provider exception after exhausting retries', function () {
    Http::fake([EB::BASE.'/accounts/uid-1/balances' => Http::response(['message' => 'down'], 500)]);

    expect(fn () => $this->provider->fetchBalance('uid-1'))->toThrow(BankProviderException::class, 'HTTP 500');
    Http::assertSentCount(3);
});

it('starts an authorization and completes the session', function () {
    Http::fake([
        EB::BASE.'/auth' => Http::response(['url' => 'https://bank.example/authorize', 'authorization_id' => 'auth-1']),
        EB::BASE.'/sessions' => Http::response(EB::session()),
    ]);

    $aspsp = new Aspsp('BBVA', 'ES', null, 90 * 86_400);
    $url = $this->provider->startAuth($aspsp, 'https://app.test/callback', 'state-1', SpanishCalendar::date('2027-01-23'));
    $session = $this->provider->completeAuth('code-1');

    expect($url)->toBe('https://bank.example/authorize')
        ->and($session->sessionId)->toBe('session-1')
        ->and($session->validUntil->toDateString())->toBe('2027-01-23')
        ->and($session->accounts[0]->uid)->toBe('uid-1')
        ->and($session->accounts[0]->iban)->toBe('ES91 •••• 1332');

    Http::assertSent(fn (Request $request) => $request->url() === EB::BASE.'/auth'
        && $request['aspsp'] === ['name' => 'BBVA', 'country' => 'ES']
        && $request['state'] === 'state-1'
        && $request['redirect_url'] === 'https://app.test/callback'
        && $request['psu_type'] === 'personal');
});

it('lists the accounts of a session', function () {
    Http::fake([
        EB::BASE.'/sessions/session-1' => Http::response(['status' => 'AUTHORIZED', 'accounts' => ['uid-1'], 'accounts_data' => [['uid' => 'uid-1', 'identification_hash' => 'hash-1']]]),
        EB::BASE.'/accounts/uid-1/details' => Http::response(EB::bankAccount('uid-1', 'ignored', 'Tarjeta', 'CARD')),
    ]);

    $accounts = $this->provider->listAccounts('session-1');

    expect($accounts)->toHaveCount(1)
        ->and($accounts[0]->identificationHash)->toBe('hash-1')
        ->and($accounts[0]->suggestedAccountType()->value)->toBe('credit_card');
});

it('treats an unknown session as already revoked', function () {
    Http::fake([EB::BASE.'/sessions/gone' => Http::response(['error' => 'not found'], 404)]);

    $this->provider->revoke('gone');

    Http::assertSent(fn (Request $request) => $request->method() === 'DELETE');
});
