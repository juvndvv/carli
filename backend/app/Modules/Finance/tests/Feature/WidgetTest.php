<?php

use App\Core\Push\RefreshWidgets;
use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Queue;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-28')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000, 'initial_balance_date' => '2026-10-01']);
    F::income($this->user, $this->account, 200000, '2026-10-20');
    F::expense($this->user, $this->account, 3000, '2026-10-25', 'Restaurantes', ['payee' => 'Bar Manolo']);
    F::expense($this->user, $this->account, 1240, '2026-10-28', 'Taxi', ['payee' => 'Cabify']);
    $this->travel(5)->minutes();
    F::expense($this->user, $this->account, 4215, '2026-10-28', 'Supermercado', ['payee' => 'Mercadona']);
    F::expense($this->user, $this->account, 999, '2026-10-26', 'Supermercado');
    $this->actingAs($this->user);
});

it('summarises the period, today and the latest expenses for the widgets', function () {
    app(BudgetService::class)->upsert(app(PeriodService::class)->current($this->user), [
        ['category_id' => F::category($this->user, 'Alimentación')->id, 'amount_cents' => 20000],
    ]);

    $this->getJson('/api/v1/finance/widget')
        ->assertOk()
        ->assertJsonPath('data.period.spent_cents', 3000 + 1240 + 4215 + 999)
        ->assertJsonPath('data.period.budgeted_cents', 20000)
        ->assertJsonPath('data.today.spent_cents', 1240 + 4215)
        ->assertJsonPath('data.today.count', 2)
        ->assertJsonCount(3, 'data.latest')
        ->assertJsonPath('data.latest.0.name', 'Mercadona')
        ->assertJsonPath('data.latest.0.amount_cents', -4215)
        ->assertJsonPath('data.latest.1.name', 'Cabify')
        ->assertJsonPath('data.latest.2.name', 'Supermercado');
});

it('refreshes the widgets when a transaction changes', function () {
    Queue::fake();

    $expense = F::expense($this->user, $this->account, 500, '2026-10-28');
    app(TransactionService::class)->delete($expense);

    Queue::assertPushed(RefreshWidgets::class, fn (RefreshWidgets $job) => $job->userId === $this->user->id);
});
