<?php

use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Support\PeriodPresenter;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Jobs\CheckPayrollOverdue;
use App\Modules\Finance\Models\Budget;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Notifications\PayrollOverdue;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;

function periodRanges(string $userId): array
{
    return Period::query()->ownedBy($userId)->orderBy('start_date')->get()
        ->map(fn (Period $period) => [$period->start_date->toDateString(), $period->end_date?->toDateString()])
        ->all();
}

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-09-28')->setTime(10, 0));
    $this->user = F::user();
    $this->account = F::account($this->user);
});

it('follows the payday-to-payday example of the PRD', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    expect(periodRanges($this->user->id))->toBe([['2026-09-28', null]]);

    $this->travelTo(SpanishCalendar::date('2026-10-28')->setTime(9, 0));
    F::income($this->user, $this->account, 250000, '2026-10-28');
    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-27'], ['2026-10-28', null]]);

    $this->travelTo(SpanishCalendar::date('2026-11-15')->setTime(9, 0));
    F::income($this->user, $this->account, 120000, '2026-11-15', 'Extra');
    F::income($this->user, $this->account, 120000, '2026-11-15', 'Nómina', ['description' => 'Paga extra']);
    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-27'], ['2026-10-28', null]]);

    $this->travelTo(SpanishCalendar::date('2026-11-26')->setTime(9, 0));
    $early = F::income($this->user, $this->account, 250000, '2026-11-26');
    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-27'], ['2026-10-28', '2026-11-25'], ['2026-11-26', null]]);

    $closed = Period::query()->ownedBy($this->user)->where('start_date', '2026-10-28')->firstOrFail();
    expect(PeriodPresenter::label($closed))->toBe('Periodo de noviembre (28 oct – 25 nov)');

    $open = app(PeriodService::class)->current($this->user);
    expect($open->opening_transaction_id)->toBe($early->id)
        ->and($open->opened_by->value)->toBe('payroll');
});

it('does not open a period for pending payroll until it is confirmed', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->travelTo(SpanishCalendar::date('2026-10-28'));
    $pending = F::income($this->user, $this->account, 250000, '2026-10-28', 'Nómina', ['status' => 'pending']);

    expect(periodRanges($this->user->id))->toBe([['2026-09-28', null]]);

    app(TransactionService::class)->update($pending, ['status' => 'cleared']);

    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-27'], ['2026-10-28', null]]);
});

it('rebuilds limits when the opening payroll is edited or deleted', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->travelTo(SpanishCalendar::date('2026-10-30'));
    $october = F::income($this->user, $this->account, 250000, '2026-10-28');

    $service = app(TransactionService::class);
    $service->update($october, ['date' => '2026-10-29']);

    expect($service->periodsChanged)->toBeTrue()
        ->and(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-28'], ['2026-10-29', null]]);

    $service->delete($october->refresh());

    expect($service->periodsChanged)->toBeTrue()
        ->and(periodRanges($this->user->id))->toBe([['2026-09-28', null]]);

    $service->restore($october->refresh());
    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-28'], ['2026-10-29', null]]);
});

it('copies the previous budgets when a new period opens', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $first = app(PeriodService::class)->current($this->user);
    app(BudgetService::class)->upsert($first, [
        ['category_id' => F::category($this->user, 'Alimentación')->id, 'amount_cents' => 40000, 'rollover' => true],
    ]);

    $this->travelTo(SpanishCalendar::date('2026-10-28'));
    F::income($this->user, $this->account, 250000, '2026-10-28');
    $second = app(PeriodService::class)->current($this->user);

    $copied = Budget::query()->ownedBy($this->user)->where('period_id', $second->id)->get();
    expect($copied)->toHaveCount(1)
        ->and($copied->first()->amount_cents)->toBe(40000)
        ->and($copied->first()->rollover)->toBeTrue();
});

it('bootstraps an initial period at the start of the month or first transaction', function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24'));
    $period = app(PeriodService::class)->current($this->user);
    expect($period->start_date->toDateString())->toBe('2026-10-01')
        ->and($period->opened_by->value)->toBe('calendar');

    $other = F::user();
    $account = F::account($other);
    F::expense($other, $account, 1000, '2026-09-12');
    expect(periodRanges($other->id))->toBe([['2026-09-12', null]]);
});

it('absorbs the bootstrap period when earlier payrolls are registered', function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24'));
    app(PeriodService::class)->current($this->user);

    F::income($this->user, $this->account, 250000, '2026-08-28');
    F::income($this->user, $this->account, 250000, '2026-09-28');

    expect(periodRanges($this->user->id))->toBe([['2026-08-28', '2026-09-27'], ['2026-09-28', null]]);
});

it('uses the payroll recurring rule to compute the expected end', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $current = app(PeriodService::class)->current($this->user);
    expect($current->expected_end_date?->toDateString())->toBe('2026-10-27');

    app(RecurringService::class)->create($this->user, [
        'account_id' => $this->account->id,
        'category_id' => F::category($this->user, 'Nómina')->id,
        'kind' => 'income',
        'amount_cents' => 250000,
        'frequency' => 'monthly',
        'start_date' => '2026-10-26',
        'mode' => 'confirm',
    ]);

    expect(app(PeriodService::class)->current($this->user)->expected_end_date?->toDateString())->toBe('2026-10-25');
});

it('opens periods manually and moves start dates through the API', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->travelTo(SpanishCalendar::date('2026-10-24'));
    $this->actingAs($this->user);

    $this->postJson('/api/v1/finance/periods', ['start_date' => '2026-10-20'])
        ->assertCreated()
        ->assertJsonPath('data.start_date', '2026-10-20')
        ->assertJsonPath('data.opened_by', 'manual')
        ->assertJsonPath('data.is_current', true);

    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-19'], ['2026-10-20', null]]);

    $this->postJson('/api/v1/finance/periods', ['start_date' => '2026-10-20'])->assertUnprocessable();

    $open = app(PeriodService::class)->current($this->user);
    $this->patchJson("/api/v1/finance/periods/{$open->id}", ['start_date' => '2026-10-22'])
        ->assertOk()
        ->assertJsonPath('data.start_date', '2026-10-22');

    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-21'], ['2026-10-22', null]]);

    $this->patchJson("/api/v1/finance/periods/{$open->id}", ['start_date' => '2026-09-20'])->assertUnprocessable();

    $this->getJson('/api/v1/finance/periods')
        ->assertOk()
        ->assertJsonCount(2, 'data')
        ->assertJsonPath('data.0.start_date', '2026-10-22')
        ->assertJsonPath('data.1.name', 'Periodo de octubre');
});

it('keeps manual periods when rebuilding', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->travelTo(SpanishCalendar::date('2026-11-02'));
    app(PeriodService::class)->openManual($this->user, SpanishCalendar::date('2026-10-30'));
    $payroll = F::income($this->user, $this->account, 250000, '2026-11-01');

    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-29'], ['2026-10-30', null]]);

    app(PeriodService::class)->rebuild($this->user);

    expect(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-29'], ['2026-10-30', null]])
        ->and($payroll->exists)->toBeTrue();
});

it('switches to calendar months when configured', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->travelTo(SpanishCalendar::date('2026-11-10'));
    $this->actingAs($this->user);

    $this->putJson('/api/v1/finance/settings', ['period_mode' => 'calendar'])
        ->assertOk()
        ->assertJsonPath('data.period_mode', 'calendar')
        ->assertJsonPath('meta.periods_changed', true);

    expect(periodRanges($this->user->id))->toBe([
        ['2026-09-01', '2026-09-30'],
        ['2026-10-01', '2026-10-31'],
        ['2026-11-01', null],
    ]);

    $this->travelTo(SpanishCalendar::date('2026-12-02'));
    $current = app(PeriodService::class)->current($this->user);
    expect($current->start_date->toDateString())->toBe('2026-12-01')
        ->and($current->expected_end_date?->toDateString())->toBe('2026-12-31');
});

it('respects the configured minimum days between payrolls', function () {
    $this->actingAs($this->user);
    $this->putJson('/api/v1/finance/settings', ['period_min_days' => 10])->assertOk();

    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->travelTo(SpanishCalendar::date('2026-10-10'));
    F::income($this->user, $this->account, 100000, '2026-10-10');

    expect(periodRanges($this->user->id))->toBe([['2026-09-01', '2026-09-27'], ['2026-09-28', '2026-10-09'], ['2026-10-10', null]]);
});

it('waits for the pending payroll of a confirm-mode rule to compute the expected end', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $recurring = app(RecurringService::class);
    $rule = $recurring->create($this->user, [
        'account_id' => $this->account->id,
        'category_id' => F::category($this->user, 'Nómina')->id,
        'kind' => 'income',
        'amount_cents' => 250000,
        'frequency' => 'monthly',
        'start_date' => '2026-10-20',
        'mode' => 'confirm',
    ]);

    $this->travelTo(SpanishCalendar::date('2026-10-20')->setTime(6, 0));
    $recurring->materializeDue();

    expect($rule->refresh()->next_occurrence?->toDateString())->toBe('2026-11-20')
        ->and(app(PeriodService::class)->current($this->user)->expected_end_date?->toDateString())->toBe('2026-10-19');

    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(10, 0));
    Notification::fake();
    $job = new CheckPayrollOverdue('2026-10-24');
    $job->handle(app(PeriodService::class));

    expect($job->sent)->toBe(1);
    Notification::assertSentTo($this->user, PayrollOverdue::class);
});

it('skips rule occurrences that could not open a period yet', function () {
    $this->travelTo(SpanishCalendar::date('2026-11-10'));
    F::income($this->user, $this->account, 250000, '2026-11-10');
    app(RecurringService::class)->create($this->user, [
        'account_id' => $this->account->id,
        'category_id' => F::category($this->user, 'Nómina')->id,
        'kind' => 'income',
        'amount_cents' => 250000,
        'frequency' => 'monthly',
        'start_date' => '2026-11-28',
        'mode' => 'confirm',
    ]);

    expect(app(PeriodService::class)->current($this->user)->expected_end_date?->toDateString())->toBe('2026-12-27');
});

it('does not resurrect the payroll boundary of a period whose start was moved', function () {
    $this->travelTo(SpanishCalendar::date('2026-10-05'));
    $august = F::income($this->user, $this->account, 250000, '2026-08-28');
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $service = app(PeriodService::class);
    $september = Period::query()->ownedBy($this->user)->where('start_date', '2026-09-28')->firstOrFail();

    $service->moveStart($september, SpanishCalendar::date('2026-09-30'));
    expect(periodRanges($this->user->id))->toBe([['2026-08-28', '2026-09-29'], ['2026-09-30', null]]);

    app(TransactionService::class)->update($august, ['date' => '2026-08-27']);
    expect(periodRanges($this->user->id))->toBe([['2026-08-27', '2026-09-29'], ['2026-09-30', null]]);

    $service->rebuild($this->user);
    expect(periodRanges($this->user->id))->toBe([['2026-08-27', '2026-09-29'], ['2026-09-30', null]]);
});

it('computes the same limits incrementally and on rebuild for backdated payrolls', function () {
    $this->travelTo(SpanishCalendar::date('2026-10-05'));
    F::income($this->user, $this->account, 250000, '2026-08-28');
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $september = Period::query()->ownedBy($this->user)->where('start_date', '2026-09-28')->firstOrFail();
    $food = F::category($this->user, 'Alimentación');
    app(BudgetService::class)->upsert($september, [['category_id' => $food->id, 'amount_cents' => 40000, 'rollover' => false]]);

    F::income($this->user, $this->account, 250000, '2026-09-20');
    $incremental = periodRanges($this->user->id);
    app(PeriodService::class)->rebuild($this->user);

    expect($incremental)->toBe([['2026-08-28', '2026-09-19'], ['2026-09-20', null]])
        ->and(periodRanges($this->user->id))->toBe($incremental);

    $open = app(PeriodService::class)->current($this->user);
    expect(Budget::query()->ownedBy($this->user)->where('period_id', $open->id)->where('category_id', $food->id)->value('amount_cents'))->toBe(40000);
});

it('keeps budgets of a period absorbed by a rebuild', function () {
    $this->travelTo(SpanishCalendar::date('2026-11-05'));
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $october = F::income($this->user, $this->account, 250000, '2026-10-28');
    $closed = Period::query()->ownedBy($this->user)->where('start_date', '2026-09-28')->firstOrFail();
    $open = Period::query()->ownedBy($this->user)->where('start_date', '2026-10-28')->firstOrFail();
    $food = F::category($this->user, 'Alimentación');
    $leisure = F::category($this->user, 'Ocio');
    Budget::query()->ownedBy($this->user)->delete();
    app(BudgetService::class)->upsert($closed, [['category_id' => $food->id, 'amount_cents' => 40000, 'rollover' => false]]);
    app(BudgetService::class)->upsert($open, [['category_id' => $leisure->id, 'amount_cents' => 9000, 'rollover' => false]]);

    app(TransactionService::class)->delete($october);

    $remaining = app(PeriodService::class)->current($this->user);
    expect(periodRanges($this->user->id))->toBe([['2026-09-28', null]])
        ->and(Budget::query()->ownedBy($this->user)->where('period_id', $remaining->id)->pluck('category_id')->sort()->values()->all())
        ->toBe(collect([$food->id, $leisure->id])->sort()->values()->all());
});

it('opens the period of a future-dated payroll only when its date arrives', function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24'));
    $service = app(PeriodService::class);
    F::income($this->user, $this->account, 250000, '2026-09-28');
    F::expense($this->user, $this->account, 1500, '2026-10-24');
    F::income($this->user, $this->account, 250000, '2026-10-27');

    expect(periodRanges($this->user->id))->toBe([['2026-09-28', null]])
        ->and($service->current($this->user)->expected_end_date?->toDateString())->toBe('2026-10-26');

    $this->travelTo(SpanishCalendar::date('2026-10-27')->setTime(8, 0));

    expect($service->current($this->user)->start_date->toDateString())->toBe('2026-10-27')
        ->and(periodRanges($this->user->id))->toBe([['2026-09-28', '2026-10-26'], ['2026-10-27', null]]);
});
