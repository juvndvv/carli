<?php

use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-09-28')->setTime(12, 0));
    $this->user = F::user();
    $this->main = F::account($this->user);
    $this->joint = F::account($this->user, ['name' => 'Compartida', 'ownership_percent' => 50]);
    F::income($this->user, $this->main, 200000, '2026-09-28');
    $this->travelTo(SpanishCalendar::date('2026-10-10')->setTime(12, 0));
    F::transfer($this->user, $this->main, $this->joint, 30000, '2026-10-01');
    F::income($this->user, $this->joint, 30000, '2026-10-01', null, ['payee' => 'Compañero de piso']);
    $this->digi = F::expense($this->user, $this->joint, 3000, '2026-10-05', 'Supermercado', ['payee' => 'Digi']);
    F::expense($this->user, $this->joint, 1000, '2026-10-06', null);
    $this->actingAs($this->user);
});

it('counts only my share of a joint account in spending, income and net worth', function () {
    $this->getJson('/api/v1/finance/dashboard')
        ->assertOk()
        ->assertJsonPath('data.income_cents', 200000)
        ->assertJsonPath('data.expense_cents', 2000)
        ->assertJsonPath('data.uncategorized.expense_cents', 500)
        ->assertJsonPath('data.net_worth_cents', 170000 + 28000);
});

it('exposes the ownership on accounts and transactions', function () {
    $this->getJson("/api/v1/finance/accounts/{$this->joint->id}")
        ->assertOk()
        ->assertJsonPath('data.ownership_percent', 50)
        ->assertJsonPath('data.balance_cents', 56000)
        ->assertJsonPath('data.own_balance_cents', 28000);

    $this->getJson("/api/v1/finance/transactions/{$this->digi->id}")
        ->assertOk()
        ->assertJsonPath('data.amount_cents', -3000)
        ->assertJsonPath('data.own_amount_cents', -1500);
});

it('validates the ownership percent', function () {
    $this->patchJson("/api/v1/finance/accounts/{$this->joint->id}", ['ownership_percent' => 0])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('ownership_percent');

    $this->patchJson("/api/v1/finance/accounts/{$this->joint->id}", ['ownership_percent' => 100])
        ->assertOk()
        ->assertJsonPath('data.own_balance_cents', 56000);
});
