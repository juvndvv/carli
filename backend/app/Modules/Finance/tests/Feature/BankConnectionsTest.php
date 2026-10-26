<?php

use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Services\BankConnectionService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Jobs\SyncBankConnection;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;

beforeEach(function () {
    EB::configure();
    Queue::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user);
    $this->actingAs($this->user);
});

describe('banks', function () {
    it('lists the banks of a country sorted by name', function () {
        Http::fake([EB::BASE.'/aspsps*' => Http::response(EB::aspsps())]);

        $this->getJson('/api/v1/finance/bank/aspsps?country=ES')
            ->assertOk()
            ->assertJsonPath('data.0', ['name' => 'BBVA', 'country' => 'ES', 'logo' => 'https://logos/bbva.svg', 'consent_days' => 90])
            ->assertJsonPath('data.1.name', 'Revolut');

        $this->getJson('/api/v1/finance/bank/aspsps')->assertOk();
        Http::assertSentCount(1);
    });

    it('answers 503 when the provider is not configured', function () {
        config()->set('services.enable_banking.app_id', null);
        app()->forgetInstance(BankDataProvider::class);

        $this->getJson('/api/v1/finance/bank/aspsps?country=FR')
            ->assertStatus(503)
            ->assertJsonPath('message', 'Falta ENABLE_BANKING_APP_ID o la clave privada de Enable Banking.');
    });
});

describe('connecting', function () {
    beforeEach(function () {
        Http::fake([
            EB::BASE.'/aspsps*' => Http::response(EB::aspsps()),
            EB::BASE.'/auth' => Http::response(['url' => 'https://bank.example/authorize']),
            EB::BASE.'/sessions' => Http::response(EB::session('session-1', [
                EB::bankAccount('uid-1', 'hash-1'),
                EB::bankAccount('uid-2', 'hash-2', 'Tarjeta', 'CARD'),
            ])),
            EB::BASE.'/sessions/*' => Http::response([], 200),
        ]);
    });

    it('returns the authorization url with a signed state and the callback url', function () {
        $this->postJson('/api/v1/finance/bank/connections', ['aspsp_name' => 'BBVA', 'aspsp_country' => 'ES'])
            ->assertCreated()
            ->assertJsonPath('data.auth_url', 'https://bank.example/authorize');

        Http::assertSent(fn (Request $request) => $request->url() === EB::BASE.'/auth'
            && $request['redirect_url'] === url('/api/v1/finance/bank/callback')
            && str_starts_with($request['access']['valid_until'], '2027-01-22')
            && app(BankConnectionService::class)->decodeState($request['state'])['user_id'] === $this->user->id);
    });

    it('rejects unknown banks', function () {
        $this->postJson('/api/v1/finance/bank/connections', ['aspsp_name' => 'Banco Inventado', 'aspsp_country' => 'ES'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('aspsp_name');
    });

    it('creates the connection on callback and redirects to the linking screen', function () {
        $state = app(BankConnectionService::class)->encodeState($this->user->id, 'BBVA', 'ES', null);
        auth()->forgetGuards();

        $response = $this->get('/api/v1/finance/bank/callback?code=code-1&state='.urlencode($state));

        $connection = BankConnection::query()->ownedBy($this->user)->sole();
        $response->assertRedirect("/finanzas/ajustes/bancos/{$connection->id}/vincular");

        expect($connection->session_id)->toBe('session-1')
            ->and(DB::table('finance.bank_connections')->value('session_id'))->not->toContain('session-1')
            ->and($connection->status->value)->toBe('active')
            ->and($connection->valid_until->toDateString())->toBe('2027-01-23')
            ->and($connection->accounts)->toHaveCount(2)
            ->and($connection->accounts[0]['iban'])->toBe('ES91 •••• 1332');

        $this->get('/api/v1/finance/bank/callback?code=code-1&state='.urlencode($state))
            ->assertRedirect('/finanzas/ajustes/bancos?error=estado');
        expect(BankConnection::query()->ownedBy($this->user)->count())->toBe(1);
    });

    it('redirects with an error when the state is forged or the user cancels', function () {
        $this->get('/api/v1/finance/bank/callback?code=x&state=forged')->assertRedirect('/finanzas/ajustes/bancos?error=estado');
        $this->get('/api/v1/finance/bank/callback?error=access_denied&state=x')->assertRedirect('/finanzas/ajustes/bancos?error=cancelado');

        expect(BankConnection::query()->ownedBy($this->user)->exists())->toBeFalse();
    });

    it('rejects expired states', function () {
        $state = app(BankConnectionService::class)->encodeState($this->user->id, 'BBVA', 'ES', null);
        $this->travel(31)->minutes();

        $this->get('/api/v1/finance/bank/callback?code=x&state='.urlencode($state))->assertRedirect('/finanzas/ajustes/bancos?error=estado');
    });
});

describe('managing', function () {
    beforeEach(function () {
        $this->connection = EB::connection($this->user, ['accounts' => [
            ['uid' => 'uid-1', 'identification_hash' => 'hash-1', 'name' => 'Cuenta Online', 'iban' => 'ES91 •••• 1332', 'currency' => 'EUR', 'type' => 'CACC'],
            ['uid' => 'uid-2', 'identification_hash' => 'hash-2', 'name' => 'Tarjeta', 'iban' => null, 'currency' => 'EUR', 'type' => 'CARD'],
        ]]);
    });

    it('lists connections with their status and never exposes the session', function () {
        EB::connection($this->user, ['aspsp_name' => 'Revolut', 'status' => 'revoked']);

        $this->getJson('/api/v1/finance/bank/connections')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status', 'active')
            ->assertJsonPath('data.0.expires_in_days', 90)
            ->assertJsonPath('data.0.bank_accounts_count', 2)
            ->assertJsonMissingPath('data.0.session_id');

        $this->getJson('/api/v1/finance/bank/connections?include_revoked=1')->assertJsonCount(2, 'data');
    });

    it('links bank accounts to existing and new accounts and queues a sync', function () {
        $this->getJson("/api/v1/finance/bank/connections/{$this->connection->id}/accounts")
            ->assertOk()
            ->assertJsonPath('data.1.suggested_account_type', 'credit_card')
            ->assertJsonPath('data.0.linked_account', null);

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/accounts", ['accounts' => [
            ['external_account_uid' => 'uid-1', 'account_id' => $this->account->id],
            ['external_account_uid' => 'uid-2', 'account_id' => 'new', 'sync_from_date' => '2026-10-01'],
        ]])->assertOk()->assertJsonCount(2, 'data.linked_accounts');

        $card = Account::query()->ownedBy($this->user)->where('external_account_uid', 'uid-2')->sole();
        expect($this->account->refresh()->sync_from_date->toDateString())->toBe('2026-10-24')
            ->and($this->account->external_account_hash)->toBe('hash-1')
            ->and($card->name)->toBe('BBVA · Tarjeta')
            ->and($card->type->value)->toBe('credit_card')
            ->and($card->sync_from_date->toDateString())->toBe('2026-10-01');
        Queue::assertPushed(SyncBankConnection::class, fn (SyncBankConnection $job) => $job->connectionId === $this->connection->id && $job->psuIpAddress === '127.0.0.1');

        $this->getJson("/api/v1/finance/accounts/{$this->account->id}")
            ->assertJsonPath('data.bank.aspsp_name', 'BBVA')
            ->assertJsonPath('data.bank.balance_cents', null);
    });

    it('validates the linking payload', function () {
        $other = F::account(F::user());

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/accounts", ['accounts' => [
            ['external_account_uid' => 'unknown', 'account_id' => $this->account->id],
            ['external_account_uid' => 'uid-2', 'account_id' => $other->id],
        ]])->assertUnprocessable()->assertJsonValidationErrors(['accounts.1.account_id']);

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/accounts", ['accounts' => [
            ['external_account_uid' => 'unknown', 'account_id' => $this->account->id],
        ]])->assertUnprocessable()->assertJsonValidationErrors(['accounts.0.external_account_uid']);

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/accounts", ['accounts' => [
            ['external_account_uid' => 'uid-1', 'account_id' => $this->account->id, 'sync_from_date' => '2026-11-01'],
        ]])->assertUnprocessable()->assertJsonValidationErrors(['accounts.0.sync_from_date']);
    });

    it('only imports accounts in euros', function () {
        $this->connection->forceFill(['accounts' => [
            ['uid' => 'uid-1', 'identification_hash' => 'hash-1', 'name' => 'EUR', 'iban' => null, 'currency' => 'EUR', 'type' => 'CACC'],
            ['uid' => 'uid-usd', 'identification_hash' => 'hash-usd', 'name' => 'USD', 'iban' => null, 'currency' => 'USD', 'type' => 'CACC'],
        ]])->save();

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/accounts", ['accounts' => [
            ['external_account_uid' => 'uid-1', 'account_id' => $this->account->id],
            ['external_account_uid' => 'uid-usd', 'account_id' => 'new'],
        ]])->assertUnprocessable()->assertJsonValidationErrors(['accounts.1.account_id' => 'Solo se pueden importar cuentas en euros.']);

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/accounts", ['accounts' => [
            ['external_account_uid' => 'uid-1', 'account_id' => $this->account->id],
            ['external_account_uid' => 'uid-usd', 'account_id' => null],
        ]])->assertOk()->assertJsonCount(1, 'data.linked_accounts');
    });

    it('shows the bank balance and the difference with the calculated one', function () {
        EB::link($this->account, $this->connection, '2026-10-20');
        $this->account->forceFill(['initial_balance_cents' => 50000, 'bank_balance_cents' => 48766, 'bank_balance_at' => now()])->save();

        $this->getJson('/api/v1/finance/accounts')
            ->assertJsonPath('data.0.bank.balance_cents', 48766)
            ->assertJsonPath('data.0.bank.difference_cents', -1234)
            ->assertJsonPath('data.0.bank.status', 'active');
    });

    it('queues a sync now with the user present', function () {
        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/sync", [], ['User-Agent' => 'Firefox'])
            ->assertStatus(202);

        Queue::assertPushed(SyncBankConnection::class, fn (SyncBankConnection $job) => $job->psuIpAddress === '127.0.0.1' && $job->psuUserAgent === 'Firefox');
    });

    it('tells when a sync for the connection is already running', function () {
        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/sync")
            ->assertStatus(202)
            ->assertJsonPath('data.queued', true);

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/sync")
            ->assertOk()
            ->assertJson(['data' => ['queued' => false, 'already_running' => true]]);

        Queue::assertPushed(SyncBankConnection::class, 1);
    });

    it('refuses to sync an expired connection', function () {
        $this->connection->forceFill(['valid_until' => now()->subDay()])->save();

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/sync")->assertUnprocessable();
        Queue::assertNothingPushed();
    });

    it('renews the consent keeping the account links', function () {
        EB::link($this->account, $this->connection, '2026-10-20');
        $this->connection->forceFill(['status' => 'expired', 'expiry_notice_days' => 1])->save();
        Http::fake([
            EB::BASE.'/aspsps*' => Http::response(EB::aspsps()),
            EB::BASE.'/auth' => Http::response(['url' => 'https://bank.example/renew']),
            EB::BASE.'/sessions' => Http::response(EB::session('session-2', [EB::bankAccount('uid-new', 'hash-1')])),
            EB::BASE.'/sessions/session-1' => Http::response([], 200),
        ]);

        $this->postJson("/api/v1/finance/bank/connections/{$this->connection->id}/renew")
            ->assertOk()
            ->assertJsonPath('data.auth_url', 'https://bank.example/renew');
        $state = Http::recorded(fn (Request $request) => $request->url() === EB::BASE.'/auth')->first()[0]['state'];

        $this->get('/api/v1/finance/bank/callback?code=code-2&state='.urlencode($state))
            ->assertRedirect("/finanzas/ajustes/bancos/{$this->connection->id}/vincular?renovado=1");

        $this->connection->refresh();
        expect($this->connection->session_id)->toBe('session-2')
            ->and($this->connection->status->value)->toBe('active')
            ->and($this->connection->expiry_notice_days)->toBeNull()
            ->and($this->account->refresh()->external_account_uid)->toBe('uid-new')
            ->and($this->account->bank_connection_id)->toBe($this->connection->id);
        Http::assertSent(fn (Request $request) => $request->method() === 'DELETE' && $request->url() === EB::BASE.'/sessions/session-1');
    });

    it('disconnects revoking the consent and keeps imported transactions', function () {
        EB::link($this->account, $this->connection, '2026-10-20');
        $imported = new Transaction(['account_id' => $this->account->id, 'kind' => 'expense', 'amount_cents' => -500, 'date' => '2026-10-21', 'source' => 'bank', 'external_id' => 'ref-1']);
        $imported->user_id = $this->user->id;
        $imported->save();
        Http::fake([EB::BASE.'/sessions/session-1' => Http::response([], 200)]);

        $this->deleteJson("/api/v1/finance/bank/connections/{$this->connection->id}")->assertNoContent();

        Http::assertSent(fn (Request $request) => $request->method() === 'DELETE');
        expect($this->connection->refresh()->status->value)->toBe('revoked')
            ->and($this->connection->session_id)->toBeNull()
            ->and($this->account->refresh()->bank_connection_id)->toBeNull()
            ->and(Transaction::query()->whereKey($imported->id)->exists())->toBeTrue();

        $this->getJson("/api/v1/finance/transactions/{$imported->id}")
            ->assertJsonPath('data.source', 'bank')
            ->assertJsonPath('data.bank', ['aspsp_name' => null]);
    });

    it('disconnects even when the bank cannot revoke the session', function () {
        EB::link($this->account, $this->connection, '2026-10-20');
        Http::fake([EB::BASE.'/sessions/session-1' => Http::response(['message' => 'Bad request'], 400)]);

        $this->deleteJson("/api/v1/finance/bank/connections/{$this->connection->id}")->assertNoContent();

        expect($this->connection->refresh()->status->value)->toBe('revoked')
            ->and($this->account->refresh()->bank_connection_id)->toBeNull();
    });

    it('disconnects an expired connection without calling the bank', function () {
        $this->connection->forceFill(['valid_until' => now()->subDay()])->save();
        Http::fake();

        $this->deleteJson("/api/v1/finance/bank/connections/{$this->connection->id}")->assertNoContent();

        Http::assertNothingSent();
        expect($this->connection->refresh()->status->value)->toBe('revoked');
    });

    it('hides other users connections', function () {
        $foreign = EB::connection(F::user());

        $this->getJson("/api/v1/finance/bank/connections/{$foreign->id}")->assertNotFound();
        $this->deleteJson("/api/v1/finance/bank/connections/{$foreign->id}")->assertNotFound();
    });
});
