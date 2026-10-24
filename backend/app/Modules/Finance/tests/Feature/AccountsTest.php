<?php

use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->actingAs($this->user);
});

it('creates accounts and computes balances from movements', function () {
    $response = $this->postJson('/api/v1/finance/accounts', [
        'name' => 'BBVA',
        'type' => 'checking',
        'initial_balance_cents' => 100000,
        'initial_balance_date' => '2026-10-01',
        'color' => 'c1',
        'icon' => 'landmark',
    ])->assertCreated()->assertJsonPath('data.balance_cents', 100000);

    $account = Account::query()->findOrFail($response->json('data.id'));
    F::expense($this->user, $account, 4250, '2026-10-23');
    F::income($this->user, $account, 250000, '2026-10-02');
    F::expense($this->user, $account, 1000, '2026-10-24', 'Supermercado', ['status' => 'pending']);

    $this->getJson("/api/v1/finance/accounts/{$account->id}")
        ->assertOk()
        ->assertJsonPath('data.balance_cents', 100000 - 4250 + 250000 - 1000)
        ->assertJsonPath('data.pending_cents', -1000)
        ->assertJsonPath('data.cleared_balance_cents', 100000 - 4250 + 250000);
});

it('exposes credit card used and available credit and subtracts it from net worth', function () {
    $checking = F::account($this->user, ['initial_balance_cents' => 300000]);
    $card = F::account($this->user, ['name' => 'Visa', 'type' => 'credit_card', 'credit_limit_cents' => 200000, 'statement_day' => 25, 'payment_day' => 5]);
    F::expense($this->user, $card, 50000, '2026-10-20', 'Ropa');
    F::transfer($this->user, $checking, $card, 20000, '2026-10-22');

    $this->getJson("/api/v1/finance/accounts/{$card->id}")
        ->assertJsonPath('data.balance_cents', -30000)
        ->assertJsonPath('data.used_credit_cents', 30000)
        ->assertJsonPath('data.available_credit_cents', 170000);

    $this->getJson('/api/v1/finance/accounts')
        ->assertOk()
        ->assertJsonCount(2, 'data')
        ->assertJsonPath('meta.net_worth_cents', 300000 - 20000 - 30000);
});

it('excludes archived accounts and accounts outside net worth', function () {
    F::account($this->user, ['initial_balance_cents' => 100000]);
    $cash = F::account($this->user, ['name' => 'Efectivo de Ana', 'type' => 'cash', 'initial_balance_cents' => 5000, 'include_in_net_worth' => false]);
    $old = F::account($this->user, ['name' => 'Antigua', 'initial_balance_cents' => 7000]);

    $this->patchJson("/api/v1/finance/accounts/{$old->id}", ['archived' => true])->assertOk()->assertJsonPath('data.archived', true);

    $this->getJson('/api/v1/finance/accounts')
        ->assertJsonCount(2, 'data')
        ->assertJsonPath('meta.net_worth_cents', 100000);

    $this->getJson('/api/v1/finance/accounts?include_archived=1')->assertJsonCount(3, 'data');
    expect($cash->exists)->toBeTrue();
});

it('refuses to delete accounts with movements', function () {
    $account = F::account($this->user);
    $empty = F::account($this->user, ['name' => 'Vacía']);
    F::expense($this->user, $account, 1000, '2026-10-20');

    $this->deleteJson("/api/v1/finance/accounts/{$account->id}")->assertUnprocessable();
    $this->deleteJson("/api/v1/finance/accounts/{$empty->id}")->assertNoContent();
});

it('reconciles an account by creating an adjustment', function () {
    $account = F::account($this->user, ['initial_balance_cents' => 100000]);
    F::expense($this->user, $account, 2500, '2026-10-20');

    $this->postJson("/api/v1/finance/accounts/{$account->id}/reconcile", ['actual_balance_cents' => 96000])
        ->assertCreated()
        ->assertJsonPath('data.difference_cents', -1500)
        ->assertJsonPath('data.adjustment.kind', 'adjustment')
        ->assertJsonPath('data.adjustment.amount_cents', -1500)
        ->assertJsonPath('data.account.balance_cents', 96000);

    $this->postJson("/api/v1/finance/accounts/{$account->id}/reconcile", ['actual_balance_cents' => 96000])
        ->assertOk()
        ->assertJsonPath('data.adjustment', null)
        ->assertJsonPath('data.difference_cents', 0);

    expect(Transaction::query()->where('kind', 'adjustment')->count())->toBe(1);
});

it('reconciles against the cleared balance, leaving pending charges untouched', function () {
    $account = F::account($this->user, ['initial_balance_cents' => 100000]);
    F::expense($this->user, $account, 2500, '2026-10-20');
    F::expense($this->user, $account, 1399, '2026-10-24', 'Supermercado', ['status' => 'pending']);

    $this->postJson("/api/v1/finance/accounts/{$account->id}/reconcile", ['actual_balance_cents' => 97500])
        ->assertOk()
        ->assertJsonPath('data.adjustment', null)
        ->assertJsonPath('data.difference_cents', 0)
        ->assertJsonPath('data.account.cleared_balance_cents', 97500)
        ->assertJsonPath('data.account.pending_cents', -1399);

    $this->postJson("/api/v1/finance/accounts/{$account->id}/reconcile", ['actual_balance_cents' => 97000])
        ->assertCreated()
        ->assertJsonPath('data.difference_cents', -500)
        ->assertJsonPath('data.account.cleared_balance_cents', 97000);
});

it('creates transfers as two atomic legs that do not count as income or spending', function () {
    $checking = F::account($this->user, ['initial_balance_cents' => 100000]);
    $savings = F::account($this->user, ['name' => 'Ahorro', 'type' => 'savings']);

    $response = $this->postJson('/api/v1/finance/transfers', [
        'from_account_id' => $checking->id,
        'to_account_id' => $savings->id,
        'amount_cents' => 30000,
        'date' => '2026-10-24',
        'description' => 'Ahorro mensual',
    ])->assertCreated();

    $group = $response->json('data.transfer_group_id');
    expect(Transaction::query()->where('transfer_group_id', $group)->pluck('amount_cents')->sort()->values()->all())->toBe([-30000, 30000])
        ->and($response->json('data.from.transfer_account_id'))->toBe($savings->id)
        ->and($response->json('data.to.category'))->toBeNull();

    $this->getJson("/api/v1/finance/accounts/{$checking->id}")->assertJsonPath('data.balance_cents', 70000);
    $this->getJson("/api/v1/finance/accounts/{$savings->id}")->assertJsonPath('data.balance_cents', 30000);

    $this->getJson('/api/v1/finance/summary')->assertJsonPath('data.spent_cents', 0)->assertJsonPath('data.income_cents', 0);

    $legId = $response->json('data.from.id');
    $this->patchJson("/api/v1/finance/transactions/{$legId}", ['amount_cents' => 35000])->assertOk()->assertJsonPath('data.amount_cents', -35000);
    $this->getJson("/api/v1/finance/accounts/{$savings->id}")->assertJsonPath('data.balance_cents', 35000);

    $this->deleteJson("/api/v1/finance/transactions/{$legId}")->assertOk();
    expect(Transaction::query()->where('transfer_group_id', $group)->count())->toBe(0);

    $this->postJson('/api/v1/finance/transfers', [
        'from_account_id' => $checking->id,
        'to_account_id' => $checking->id,
        'amount_cents' => 100,
        'date' => '2026-10-24',
    ])->assertUnprocessable()->assertJsonValidationErrors('to_account_id');
});
