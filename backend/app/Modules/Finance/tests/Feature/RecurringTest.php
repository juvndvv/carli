<?php

use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\RecurringPending;
use App\Modules\Finance\Notifications\UpcomingCharge;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-01')->setTime(7, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000]);
    $this->actingAs($this->user);
});

function createRule(object $test, array $overrides = []): array
{
    return $test->postJson('/api/v1/finance/recurring-rules', array_merge([
        'account_id' => $test->account->id,
        'category_id' => F::category($test->user, 'Streaming')->id,
        'kind' => 'expense',
        'amount_cents' => 1399,
        'payee' => 'Netflix',
        'frequency' => 'monthly',
        'start_date' => '2026-10-05',
        'mode' => 'auto',
        'is_subscription' => true,
    ], $overrides))->assertCreated()->json('data');
}

it('creates rules with normalized sign, next occurrence and costs', function () {
    $rule = createRule($this);

    expect($rule['amount_cents'])->toBe(-1399)
        ->and($rule['next_occurrence'])->toBe('2026-10-05')
        ->and($rule['monthly_cost_cents'])->toBe(-1399)
        ->and($rule['yearly_cost_cents'])->toBe(-16788)
        ->and($rule['remind_days_before'])->toBe(2);

    createRule($this, ['payee' => 'Spotify', 'amount_cents' => 10788, 'frequency' => 'yearly']);

    $this->getJson('/api/v1/finance/recurring-rules?subscriptions=1')
        ->assertJsonCount(2, 'data')
        ->assertJsonPath('meta.subscriptions.count', 2)
        ->assertJsonPath('meta.subscriptions.monthly_cents', -1399 - 899)
        ->assertJsonPath('meta.subscriptions.yearly_cents', -16788 - 10788);
});

it('materializes due occurrences idempotently', function () {
    createRule($this, ['start_date' => '2026-08-05']);

    $this->artisan('finance:materialize-recurring')->assertSuccessful();
    $this->artisan('finance:materialize-recurring')->assertSuccessful();

    $transactions = Transaction::query()->whereNotNull('recurring_rule_id')->orderBy('date')->get();
    expect($transactions->pluck('date')->map->toDateString()->all())->toBe(['2026-08-05', '2026-09-05'])
        ->and($transactions->pluck('status')->map->value->unique()->all())->toBe(['cleared'])
        ->and(RecurringRule::query()->first()?->next_occurrence?->toDateString())->toBe('2026-10-05');

    $rule = RecurringRule::query()->firstOrFail();
    $rule->next_occurrence = SpanishCalendar::date('2026-09-05');
    $rule->save();
    $this->artisan('finance:materialize-recurring')->assertSuccessful();

    expect(Transaction::query()->whereNotNull('recurring_rule_id')->count())->toBe(2)
        ->and($rule->refresh()->next_occurrence?->toDateString())->toBe('2026-10-05');

    $this->travelTo(SpanishCalendar::date('2026-10-05')->setTime(6, 0));
    $this->artisan('finance:materialize-recurring')->assertSuccessful();
    expect(Transaction::query()->whereNotNull('recurring_rule_id')->count())->toBe(3);
});

it('creates pending occurrences in confirm mode and confirms them with a different amount', function () {
    $rule = createRule($this, ['mode' => 'confirm', 'start_date' => '2026-10-01']);

    $this->artisan('finance:materialize-recurring')->assertSuccessful();
    $pending = Transaction::query()->where('recurring_rule_id', $rule['id'])->firstOrFail();
    expect($pending->status->value)->toBe('pending');

    $this->travelTo(SpanishCalendar::date('2026-10-01')->setTime(9, 0));
    $this->artisan('finance:upcoming-charges')->assertSuccessful();
    Notification::assertSentTo($this->user, RecurringPending::class);

    $this->postJson("/api/v1/finance/recurring-rules/{$rule['id']}/confirm", ['amount_cents' => 1599, 'update_rule_amount' => true])
        ->assertOk()
        ->assertJsonPath('data.transaction.status', 'cleared')
        ->assertJsonPath('data.transaction.amount_cents', -1599)
        ->assertJsonPath('data.price_changed', true)
        ->assertJsonPath('data.previous_amount_cents', -1399)
        ->assertJsonPath('data.rule.amount_cents', -1599)
        ->assertJsonPath('data.rule.pending_transaction', null);

    $this->postJson("/api/v1/finance/recurring-rules/{$rule['id']}/confirm")
        ->assertOk()
        ->assertJsonPath('data.transaction.date', '2026-11-01')
        ->assertJsonPath('data.price_changed', false)
        ->assertJsonPath('data.rule.next_occurrence', '2026-12-01');
});

it('confirming a payroll occurrence opens a new period', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $rule = createRule($this, [
        'category_id' => F::category($this->user, 'Nómina')->id,
        'kind' => 'income',
        'amount_cents' => 250000,
        'payee' => 'ACME',
        'start_date' => '2026-10-28',
        'mode' => 'confirm',
        'is_subscription' => false,
    ]);

    expect(app(PeriodService::class)->current($this->user)->expected_end_date?->toDateString())->toBe('2026-10-27');

    $this->travelTo(SpanishCalendar::date('2026-10-28')->setTime(6, 0));
    $this->artisan('finance:materialize-recurring')->assertSuccessful();
    expect(app(PeriodService::class)->current($this->user)->start_date->toDateString())->toBe('2026-09-28');

    $this->postJson("/api/v1/finance/recurring-rules/{$rule['id']}/confirm")->assertOk();
    $current = app(PeriodService::class)->current($this->user);
    expect($current->start_date->toDateString())->toBe('2026-10-28')
        ->and($current->expected_end_date?->toDateString())->toBe('2026-11-27');
});

it('sends upcoming charge reminders the configured days before', function () {
    createRule($this, ['start_date' => '2026-10-05']);

    $this->travelTo(SpanishCalendar::date('2026-10-02')->setTime(9, 0));
    $this->artisan('finance:upcoming-charges')->assertSuccessful();
    Notification::assertNothingSent();

    $this->travelTo(SpanishCalendar::date('2026-10-03')->setTime(9, 0));
    $this->artisan('finance:upcoming-charges')->assertSuccessful();
    Notification::assertSentTo($this->user, UpcomingCharge::class, fn (UpcomingCharge $notification) => $notification->title() === 'Netflix 13,99 € pasado mañana'
        && $notification->toArray($this->user)['type'] === 'upcoming_charge');
});

it('cancels, updates and deletes rules', function () {
    $rule = createRule($this);

    $this->patchJson("/api/v1/finance/recurring-rules/{$rule['id']}", ['cancelled' => true])
        ->assertOk()
        ->assertJsonPath('data.cancelled', true)
        ->assertJsonPath('data.active', false);

    $this->getJson('/api/v1/finance/recurring-rules')->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/finance/recurring-rules?include_cancelled=1')->assertJsonCount(1, 'data');

    $this->patchJson("/api/v1/finance/recurring-rules/{$rule['id']}", ['cancelled' => false, 'day_of_month' => 20])
        ->assertOk()
        ->assertJsonPath('data.next_occurrence', '2026-10-20');

    $this->deleteJson("/api/v1/finance/recurring-rules/{$rule['id']}")->assertNoContent();
});

it('lists upcoming charges in the dashboard', function () {
    createRule($this, ['start_date' => '2026-10-05']);
    createRule($this, ['payee' => 'Gimnasio', 'start_date' => '2026-10-20']);

    $this->getJson('/api/v1/finance/dashboard')
        ->assertJsonCount(1, 'data.upcoming')
        ->assertJsonPath('data.upcoming.0.name', 'Netflix')
        ->assertJsonPath('data.upcoming.0.date', '2026-10-05');
});
