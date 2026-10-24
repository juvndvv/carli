<?php

use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Notifications\BudgetThresholdReached;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-10')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 500000]);
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->period = app(PeriodService::class)->current($this->user);
    $this->actingAs($this->user);
});

it('upserts budgets and computes consumption including child categories', function () {
    $food = F::category($this->user, 'Alimentación');
    $leisure = F::category($this->user, 'Ocio');

    $this->putJson('/api/v1/finance/budgets', [
        'period_id' => $this->period->id,
        'budgets' => [
            ['category_id' => $food->id, 'amount_cents' => 40000],
            ['category_id' => $leisure->id, 'amount_cents' => 10000, 'rollover' => true],
        ],
    ])->assertOk()->assertJsonCount(2, 'data');

    F::expense($this->user, $this->account, 12000, '2026-09-30', 'Supermercado');
    F::expense($this->user, $this->account, 8000, '2026-10-02', 'Restaurantes');
    F::expense($this->user, $this->account, 5000, '2026-10-05', 'Alimentación');

    $response = $this->getJson('/api/v1/finance/budgets?period_id='.$this->period->id)->assertOk();
    $rows = collect($response->json('data'))->keyBy('category.name');

    expect($rows['Alimentación']['spent_cents'])->toBe(25000)
        ->and($rows['Alimentación']['remaining_cents'])->toBe(15000)
        ->and($rows['Alimentación']['percent_bp'])->toBe(6250)
        ->and($rows['Alimentación']['status'])->toBe('ok')
        ->and($rows['Ocio']['spent_cents'])->toBe(0)
        ->and($response->json('meta.totals.budgeted_cents'))->toBe(50000)
        ->and($response->json('meta.totals.spent_cents'))->toBe(25000);

    $elapsed = $response->json('meta.period.days_elapsed');
    $total = $response->json('meta.period.days_total');
    expect($rows['Alimentación']['projected_cents'])->toBe((int) round(25000 * $total / $elapsed));

    $this->putJson('/api/v1/finance/budgets', [
        'period_id' => $this->period->id,
        'budgets' => [['category_id' => $leisure->id, 'amount_cents' => null]],
    ])->assertOk()->assertJsonCount(1, 'data');

    $this->putJson('/api/v1/finance/budgets', [
        'budgets' => [['category_id' => F::category($this->user, 'Nómina')->id, 'amount_cents' => 100]],
    ])->assertUnprocessable();
});

it('excludes the share of shared expenses from own spending', function () {
    $food = F::category($this->user, 'Alimentación');
    $this->putJson('/api/v1/finance/budgets', ['budgets' => [['category_id' => $food->id, 'amount_cents' => 10000]]])->assertOk();
    $ana = $this->postJson('/api/v1/finance/contacts', ['name' => 'Ana'])->json('data.id');

    $this->postJson('/api/v1/finance/transactions', [
        'account_id' => $this->account->id,
        'kind' => 'expense',
        'amount_cents' => -8000,
        'date' => '2026-10-05',
        'category_id' => F::category($this->user, 'Restaurantes')->id,
        'shares' => ['mode' => 'percentage', 'items' => [['contact_id' => $ana, 'percentage' => 50]]],
    ])->assertCreated()
        ->assertJsonPath('data.own_amount_cents', -4000)
        ->assertJsonPath('data.shares.0.name', 'Ana')
        ->assertJsonPath('data.shares.0.amount_cents', 4000);

    $this->getJson('/api/v1/finance/budgets')->assertJsonPath('data.0.spent_cents', 4000);
    $this->getJson('/api/v1/finance/summary')->assertJsonPath('data.spent_cents', 4000);
    $this->getJson('/api/v1/finance/dashboard')->assertJsonPath('data.expense_cents', 4000)
        ->assertJsonPath('data.by_category.0.name', 'Alimentación')
        ->assertJsonPath('data.by_category.0.amount_cents', 4000);
});

it('applies rollover from the previous period', function () {
    $leisure = F::category($this->user, 'Ocio');
    $this->putJson('/api/v1/finance/budgets', ['budgets' => [['category_id' => $leisure->id, 'amount_cents' => 10000, 'rollover' => true]]])->assertOk();
    F::expense($this->user, $this->account, 6000, '2026-10-01', 'Cine y espectáculos');

    $this->travelTo(SpanishCalendar::date('2026-10-28'));
    F::income($this->user, $this->account, 250000, '2026-10-28');

    $this->getJson('/api/v1/finance/budgets')
        ->assertJsonPath('data.0.amount_cents', 10000)
        ->assertJsonPath('data.0.rollover_in_cents', 4000)
        ->assertJsonPath('data.0.available_cents', 14000);
});

it('copies budgets between periods', function () {
    $food = F::category($this->user, 'Alimentación');
    $this->putJson('/api/v1/finance/budgets', ['budgets' => [['category_id' => $food->id, 'amount_cents' => 30000]]])->assertOk();

    $this->travelTo(SpanishCalendar::date('2026-10-30'));
    $next = app(PeriodService::class)->openManual($this->user, SpanishCalendar::date('2026-10-30'));
    $this->putJson('/api/v1/finance/budgets', ['period_id' => $next->id, 'budgets' => [['category_id' => $food->id, 'amount_cents' => null]]])->assertOk()->assertJsonCount(0, 'data');

    $this->postJson('/api/v1/finance/budgets/copy', ['from_period_id' => $this->period->id, 'to_period_id' => $next->id])
        ->assertOk()
        ->assertJsonPath('meta.copied', 1)
        ->assertJsonPath('data.0.amount_cents', 30000);
});

it('notifies 80 and 100 percent thresholds once per budget', function () {
    $food = F::category($this->user, 'Alimentación');
    $this->putJson('/api/v1/finance/budgets', ['budgets' => [['category_id' => $food->id, 'amount_cents' => 10000]]])->assertOk();

    F::expense($this->user, $this->account, 5000, '2026-10-01', 'Supermercado');
    Notification::assertNothingSent();

    F::expense($this->user, $this->account, 3500, '2026-10-02', 'Supermercado');
    Notification::assertSentToTimes($this->user, BudgetThresholdReached::class, 1);
    Notification::assertSentTo($this->user, BudgetThresholdReached::class, fn (BudgetThresholdReached $notification) => $notification->threshold === 80
        && $notification->toArray($this->user)['module'] === 'finance'
        && $notification->toArray($this->user)['type'] === 'budget_threshold'
        && str_starts_with($notification->toArray($this->user)['url'], '/finanzas/presupuestos'));

    F::expense($this->user, $this->account, 500, '2026-10-03', 'Supermercado');
    Notification::assertSentToTimes($this->user, BudgetThresholdReached::class, 1);

    F::expense($this->user, $this->account, 1500, '2026-10-04', 'Supermercado');
    Notification::assertSentToTimes($this->user, BudgetThresholdReached::class, 2);
    Notification::assertSentTo($this->user, BudgetThresholdReached::class, fn (BudgetThresholdReached $notification) => $notification->threshold === 100);

    F::expense($this->user, $this->account, 1500, '2026-10-05', 'Supermercado');
    Notification::assertSentToTimes($this->user, BudgetThresholdReached::class, 2);

    $this->getJson('/api/v1/finance/budgets')->assertJsonPath('data.0.status', 'exceeded');
});
