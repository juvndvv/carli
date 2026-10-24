<?php

use App\Modules\Finance\Domain\Services\ContactService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Policies\OwnedByUserPolicy;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->owner = F::user();
    $this->intruder = F::user();
    $this->account = F::account($this->owner, ['initial_balance_cents' => 1000]);
    $this->transaction = F::expense($this->owner, $this->account, 500, '2026-10-20');
    $this->contact = app(ContactService::class)->create($this->owner, 'Ana', null);
    $this->period = app(PeriodService::class)->current($this->owner);
});

it('hides other users resources behind 404', function (string $method, string $uri) {
    $uri = strtr($uri, [
        '{account}' => $this->account->id,
        '{transaction}' => $this->transaction->id,
        '{category}' => F::category($this->owner, 'Ocio')->id,
        '{contact}' => $this->contact->id,
        '{period}' => $this->period->id,
    ]);

    $this->actingAs($this->intruder)->json($method, $uri, ['start_date' => '2026-10-22', 'actual_balance_cents' => 0, 'account_id' => $this->account->id])->assertNotFound();
})->with([
    ['GET', '/api/v1/finance/accounts/{account}'],
    ['PATCH', '/api/v1/finance/accounts/{account}'],
    ['DELETE', '/api/v1/finance/accounts/{account}'],
    ['POST', '/api/v1/finance/accounts/{account}/reconcile'],
    ['GET', '/api/v1/finance/transactions/{transaction}'],
    ['PATCH', '/api/v1/finance/transactions/{transaction}'],
    ['DELETE', '/api/v1/finance/transactions/{transaction}'],
    ['POST', '/api/v1/finance/transactions/{transaction}/restore'],
    ['DELETE', '/api/v1/finance/categories/{category}'],
    ['GET', '/api/v1/finance/contacts/{contact}'],
    ['POST', '/api/v1/finance/contacts/{contact}/settle'],
    ['PATCH', '/api/v1/finance/periods/{period}'],
]);

it('rejects foreign ids inside payloads', function () {
    $own = F::account($this->intruder);

    $this->actingAs($this->intruder)->postJson('/api/v1/finance/transactions', [
        'account_id' => $this->account->id,
        'kind' => 'expense',
        'amount_cents' => -100,
        'date' => '2026-10-24',
    ])->assertUnprocessable()->assertJsonValidationErrors('account_id');

    $this->actingAs($this->intruder)->postJson('/api/v1/finance/transfers', [
        'from_account_id' => $own->id,
        'to_account_id' => $this->account->id,
        'amount_cents' => 100,
        'date' => '2026-10-24',
    ])->assertUnprocessable()->assertJsonValidationErrors('to_account_id');

    $this->actingAs($this->intruder)->patchJson('/api/v1/finance/transactions/bulk', [
        'ids' => [$this->transaction->id],
        'category_id' => null,
    ])->assertUnprocessable();

    $this->actingAs($this->intruder)->getJson('/api/v1/finance/budgets?period_id='.$this->period->id)->assertUnprocessable();
    $this->actingAs($this->intruder)->getJson('/api/v1/finance/transactions')->assertOk()->assertJsonCount(0, 'data');
    $this->actingAs($this->intruder)->getJson('/api/v1/finance/accounts')->assertOk()->assertJsonCount(1, 'data');
});

it('denies through the policy when a model of another user reaches it', function () {
    $policy = new OwnedByUserPolicy;

    expect($policy->view($this->owner, $this->account))->toBeTrue()
        ->and($policy->update($this->intruder, $this->account))->toBeFalse()
        ->and($policy->delete($this->intruder, Transaction::query()->withoutGlobalScopes()->findOrFail($this->transaction->id)))->toBeFalse();
});

it('requires authentication', function () {
    $this->getJson('/api/v1/finance/accounts')->assertUnauthorized();
    expect(Account::query()->withoutGlobalScopes()->count())->toBe(1);
});

it('blocks the finance API while the module is disabled', function () {
    $this->actingAs($this->owner)->patchJson('/api/v1/modules/finance', ['enabled' => false])->assertOk();

    $this->getJson('/api/v1/finance/accounts')->assertForbidden();
    $this->getJson("/api/v1/finance/transactions/{$this->transaction->id}")->assertForbidden();

    $this->patchJson('/api/v1/modules/finance', ['enabled' => true])->assertOk();

    $this->getJson('/api/v1/finance/accounts')->assertOk();
});
