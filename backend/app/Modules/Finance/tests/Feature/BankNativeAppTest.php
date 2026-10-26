<?php

use App\Modules\Finance\BankSync\Data\BankReturnTarget;
use App\Modules\Finance\BankSync\Services\BankConnectionService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\BankConnection;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Http\Client\Request;
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

it('keeps the web callback url and remembers that the native app started the flow', function () {
    Http::fake([
        EB::BASE.'/aspsps*' => Http::response(EB::aspsps()),
        EB::BASE.'/auth' => Http::response(['url' => 'https://bank.example/authorize']),
    ]);

    $this->postJson('/api/v1/finance/bank/connections', ['aspsp_name' => 'BBVA', 'aspsp_country' => 'ES', 'return_to' => 'app'])
        ->assertCreated()
        ->assertJsonPath('data.auth_url', 'https://bank.example/authorize');

    Http::assertSent(fn (Request $request) => $request->url() === EB::BASE.'/auth'
        && $request['redirect_url'] === url('/api/v1/finance/bank/callback')
        && app(BankConnectionService::class)->decodeState($request['state'])['return_to'] === BankReturnTarget::App);
});

it('defaults to the web flow and rejects unknown return targets', function () {
    $state = app(BankConnectionService::class)->encodeState($this->user->id, 'BBVA', 'ES', null);
    expect(app(BankConnectionService::class)->returnTargetOf($state))->toBe(BankReturnTarget::Web);

    $this->postJson('/api/v1/finance/bank/connections', ['aspsp_name' => 'BBVA', 'aspsp_country' => 'ES', 'return_to' => 'desktop'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('return_to');
});

it('sends the native app back to its url scheme with the new connection', function () {
    Http::fake([EB::BASE.'/sessions' => Http::response(EB::session('session-1', [EB::bankAccount('uid-1', 'hash-1')]))]);
    $state = app(BankConnectionService::class)->encodeState($this->user->id, 'BBVA', 'ES', null, BankReturnTarget::App);
    auth()->forgetGuards();

    $response = $this->get('/api/v1/finance/bank/callback?code=code-1&state='.urlencode($state));

    $connection = BankConnection::query()->ownedBy($this->user)->sole();
    $response->assertRedirect("carli://bank/callback?connection={$connection->id}");
});

it('sends the native app back with the reason when the flow fails', function () {
    $state = app(BankConnectionService::class)->encodeState($this->user->id, 'BBVA', 'ES', null, BankReturnTarget::App);

    $this->get('/api/v1/finance/bank/callback?error=access_denied&state='.urlencode($state))
        ->assertRedirect('carli://bank/callback?error=cancelado');

    $this->get('/api/v1/finance/bank/callback?code=x&state='.urlencode($state))
        ->assertRedirect('carli://bank/callback?error=proveedor');

    $this->get('/api/v1/finance/bank/callback?code=x&state='.urlencode($state))
        ->assertRedirect('carli://bank/callback?error=estado');

    $this->get('/api/v1/finance/bank/callback?code=x&state=forged')
        ->assertRedirect('/finanzas/ajustes/bancos?error=estado');
});

it('marks renewals started from the native app', function () {
    $connection = EB::connection($this->user);
    Http::fake([
        EB::BASE.'/aspsps*' => Http::response(EB::aspsps()),
        EB::BASE.'/auth' => Http::response(['url' => 'https://bank.example/renew']),
        EB::BASE.'/sessions' => Http::response(EB::session('session-2', [EB::bankAccount('uid-new', 'hash-1')])),
        EB::BASE.'/sessions/*' => Http::response([], 200),
    ]);

    $this->postJson("/api/v1/finance/bank/connections/{$connection->id}/renew", ['return_to' => 'app'])->assertOk();
    $state = Http::recorded(fn (Request $request) => $request->url() === EB::BASE.'/auth')->first()[0]['state'];

    $this->get('/api/v1/finance/bank/callback?code=code-2&state='.urlencode($state))
        ->assertRedirect("carli://bank/callback?connection={$connection->id}&renovado=1");
});
