<?php

use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-09-28')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000, 'initial_balance_date' => '2026-09-01']);
    F::income($this->user, $this->account, 200000, '2026-09-28');
    F::expense($this->user, $this->account, 50000, '2026-10-01', 'Alquiler');
    F::expense($this->user, $this->account, 10000, '2026-10-10', 'Supermercado');
    $this->travelTo(SpanishCalendar::date('2026-10-28')->setTime(12, 0));
    F::income($this->user, $this->account, 210000, '2026-10-28');
    $this->travelTo(SpanishCalendar::date('2026-11-05')->setTime(12, 0));
    F::expense($this->user, $this->account, 20000, '2026-11-02', 'Supermercado');
    F::expense($this->user, $this->account, 5000, '2026-11-03', 'Cine y espectáculos');
    $this->actingAs($this->user);
});

it('returns the dashboard of the current period with comparisons', function () {
    $current = app(PeriodService::class)->current($this->user);
    app(BudgetService::class)->upsert($current, [
        ['category_id' => F::category($this->user, 'Alimentación')->id, 'amount_cents' => 25000],
        ['category_id' => F::category($this->user, 'Ocio')->id, 'amount_cents' => 10000],
    ]);

    $response = $this->getJson('/api/v1/finance/dashboard')->assertOk();

    $response->assertJsonPath('data.period.start_date', '2026-10-28')
        ->assertJsonPath('data.period.name', 'Periodo de noviembre')
        ->assertJsonPath('data.previous_period.start_date', '2026-09-28')
        ->assertJsonPath('data.income_cents', 210000)
        ->assertJsonPath('data.expense_cents', 25000)
        ->assertJsonPath('data.savings_cents', 185000)
        ->assertJsonPath('data.savings_rate_bp', 8810)
        ->assertJsonPath('data.previous.income_cents', 200000)
        ->assertJsonPath('data.previous.expense_cents', 60000)
        ->assertJsonPath('data.net_worth_cents', 100000 + 200000 - 60000 + 210000 - 25000)
        ->assertJsonPath('data.net_worth_previous_cents', 100000 + 200000 - 60000)
        ->assertJsonPath('data.by_category.0.name', 'Alimentación')
        ->assertJsonPath('data.by_category.0.amount_cents', 20000)
        ->assertJsonPath('data.by_category.0.percent_bp', 8000)
        ->assertJsonPath('data.by_category.0.children.0.category.name', 'Supermercado')
        ->assertJsonPath('data.budgets.top.0.category.name', 'Alimentación')
        ->assertJsonPath('data.budgets.top.0.percent_bp', 8000)
        ->assertJsonPath('data.budgets.totals.budgeted_cents', 35000)
        ->assertJsonCount(2, 'data.history')
        ->assertJsonPath('data.history.0.label', 'oct')
        ->assertJsonPath('data.history.0.expense_cents', 60000)
        ->assertJsonPath('data.history.1.net_worth_cents', 100000 + 200000 - 60000 + 210000 - 25000)
        ->assertJsonCount(5, 'data.recent_transactions')
        ->assertJsonPath('data.recent_transactions.0.date', '2026-11-03');

    $previous = $response->json('data.previous_period.id');
    $this->getJson('/api/v1/finance/dashboard?period_id='.$previous)
        ->assertJsonPath('data.period.start_date', '2026-09-28')
        ->assertJsonPath('data.expense_cents', 60000)
        ->assertJsonPath('data.previous_period', null);
});

it('returns the home summary', function () {
    $this->getJson('/api/v1/finance/summary')
        ->assertOk()
        ->assertJsonPath('data.spent_cents', 25000)
        ->assertJsonPath('data.income_cents', 210000)
        ->assertJsonPath('data.period.label', 'Periodo de noviembre (28 oct – 27 nov)')
        ->assertJsonPath('data.remaining_days', 23)
        ->assertJsonPath('data.net_worth_cents', 100000 + 200000 - 60000 + 210000 - 25000);
});
