<?php

use App\Core\Notifications\NotificationPreferenceService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\DebtReminder;
use App\Modules\Finance\Notifications\GoalReached;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 500000]);
    app(NotificationPreferenceService::class)->update($this->user, [
        ['module' => 'finance', 'type' => 'goal_reached', 'push' => false, 'in_app' => true],
    ]);
    $this->actingAs($this->user);
});

it('tracks partial payments and closes the debt when fully paid', function () {
    $ana = $this->postJson('/api/v1/finance/contacts', ['name' => 'Ana'])->json('data.id');
    $debt = $this->postJson('/api/v1/finance/debts', [
        'name' => 'Préstamo de Ana',
        'direction' => 'i_owe',
        'contact_id' => $ana,
        'principal_cents' => 30000,
        'start_date' => '2026-10-01',
        'due_date' => '2026-12-31',
    ])->assertCreated()->assertJsonPath('data.pending_cents', 30000)->json('data');

    $this->postJson("/api/v1/finance/debts/{$debt['id']}/payments", ['account_id' => $this->account->id, 'amount_cents' => 10000, 'date' => '2026-10-10'])
        ->assertCreated()
        ->assertJsonPath('data.amount_cents', -10000)
        ->assertJsonPath('data.debt_id', $debt['id'])
        ->assertJsonPath('meta.debt.paid_cents', 10000)
        ->assertJsonPath('meta.debt.pending_cents', 20000)
        ->assertJsonPath('meta.debt.progress_bp', 3333);

    $this->getJson("/api/v1/finance/contacts/{$ana}")->assertJsonPath('data.balance_cents', -20000)->assertJsonPath('data.i_owe_cents', 20000);
    $this->getJson('/api/v1/finance/debts')->assertJsonPath('meta.i_owe_cents', 20000);

    $this->postJson("/api/v1/finance/debts/{$debt['id']}/payments", ['account_id' => $this->account->id, 'amount_cents' => 20000])
        ->assertJsonPath('meta.debt.closed', true);

    $this->getJson('/api/v1/finance/debts')->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/finance/debts?include_closed=1')->assertJsonCount(1, 'data');
    $this->getJson("/api/v1/finance/debts/{$debt['id']}/payments")->assertJsonCount(2, 'data');
});

it('tracks money owed to me', function () {
    $debt = $this->postJson('/api/v1/finance/debts', [
        'name' => 'Dinero prestado a Luis',
        'direction' => 'owed_to_me',
        'principal_cents' => 5000,
        'start_date' => '2026-10-01',
    ])->json('data');

    $this->postJson("/api/v1/finance/debts/{$debt['id']}/payments", ['account_id' => $this->account->id, 'amount_cents' => 2000])
        ->assertJsonPath('data.kind', 'income')
        ->assertJsonPath('data.amount_cents', 2000)
        ->assertJsonPath('meta.debt.pending_cents', 3000);
});

it('creates a recurring rule for loan installments', function () {
    $debt = $this->postJson('/api/v1/finance/debts', [
        'name' => 'Préstamo coche',
        'direction' => 'i_owe',
        'principal_cents' => 600000,
        'start_date' => '2026-10-01',
        'plan' => [
            'account_id' => $this->account->id,
            'installment_cents' => 25000,
            'installments_count' => 24,
            'first_payment_date' => '2026-11-05',
            'payment_day' => 5,
        ],
    ])->assertCreated()
        ->assertJsonPath('data.installment_cents', 25000)
        ->assertJsonPath('data.installments_count', 24)
        ->assertJsonPath('data.next_payment_date', '2026-11-05')
        ->json('data');

    $rule = RecurringRule::query()->findOrFail($debt['recurring_rule_id']);
    expect($rule->amount_cents)->toBe(-25000)
        ->and($rule->end_date?->toDateString())->toBe('2028-10-05')
        ->and($rule->day_of_month)->toBe(5);

    $this->travelTo(SpanishCalendar::date('2026-12-06')->setTime(6, 0));
    $this->artisan('finance:materialize-recurring')->assertSuccessful();

    $this->getJson("/api/v1/finance/debts/{$debt['id']}")
        ->assertJsonPath('data.paid_cents', 50000)
        ->assertJsonPath('data.installments_paid', 2)
        ->assertJsonPath('data.pending_cents', 550000);
});

it('closes a debt once its last installment is paid and reopens it if a payment is removed', function () {
    $debt = $this->postJson('/api/v1/finance/debts', [
        'name' => 'Préstamo de Marta',
        'direction' => 'i_owe',
        'principal_cents' => 30000,
        'start_date' => '2026-10-01',
        'plan' => [
            'account_id' => $this->account->id,
            'installment_cents' => 10000,
            'installments_count' => 3,
            'first_payment_date' => '2026-11-05',
            'mode' => 'confirm',
        ],
    ])->assertCreated()->json('data');

    $this->travelTo(SpanishCalendar::date('2027-01-06')->setTime(6, 0));
    $this->artisan('finance:materialize-recurring')->assertSuccessful();

    $this->getJson("/api/v1/finance/debts/{$debt['id']}")
        ->assertJsonPath('data.paid_cents', 0)
        ->assertJsonPath('data.closed', false);

    $pending = Transaction::query()->where('debt_id', $debt['id'])->orderBy('date')->get();
    expect($pending)->toHaveCount(3);
    foreach ($pending as $installment) {
        $this->patchJson("/api/v1/finance/transactions/{$installment->id}", ['status' => 'cleared'])->assertOk();
    }

    $this->getJson("/api/v1/finance/debts/{$debt['id']}")
        ->assertJsonPath('data.pending_cents', 0)
        ->assertJsonPath('data.closed', true);

    $this->deleteJson("/api/v1/finance/transactions/{$pending->last()->id}")->assertSuccessful();

    $this->getJson("/api/v1/finance/debts/{$debt['id']}")
        ->assertJsonPath('data.pending_cents', 10000)
        ->assertJsonPath('data.closed', false);
});

it('reminds debts on their due date', function () {
    $this->postJson('/api/v1/finance/debts', [
        'name' => 'Devolver a Ana',
        'direction' => 'i_owe',
        'principal_cents' => 5000,
        'start_date' => '2026-10-01',
        'due_date' => '2026-10-26',
    ])->assertCreated();

    $this->artisan('finance:upcoming-charges', ['--date' => '2026-10-24'])->assertSuccessful();
    Notification::assertSentTo($this->user, DebtReminder::class, fn (DebtReminder $notification) => $notification->daysUntil === 2);
});

it('tracks manual goal contributions and the monthly amount needed', function () {
    $goal = $this->postJson('/api/v1/finance/goals', [
        'name' => 'Vacaciones',
        'target_cents' => 120000,
        'target_date' => '2027-03-31',
        'icon' => 'plane',
    ])->assertCreated()
        ->assertJsonPath('data.saved_cents', 0)
        ->assertJsonPath('data.months_left', 6)
        ->assertJsonPath('data.monthly_needed_cents', 20000)
        ->json('data');

    $this->postJson("/api/v1/finance/goals/{$goal['id']}/contributions", ['amount_cents' => 30000, 'date' => '2026-10-24'])
        ->assertCreated()
        ->assertJsonPath('meta.goal.saved_cents', 30000)
        ->assertJsonPath('meta.goal.progress_bp', 2500)
        ->assertJsonPath('meta.goal.monthly_needed_cents', 15000);

    Notification::assertSentTo($this->user, GoalReached::class, fn (GoalReached $notification) => $notification->milestone === 25);

    $contribution = $this->getJson("/api/v1/finance/goals/{$goal['id']}/contributions")->assertJsonCount(1, 'data')->json('data.0.id');
    $this->deleteJson("/api/v1/finance/goals/{$goal['id']}/contributions/{$contribution}")->assertNoContent();
    $this->getJson("/api/v1/finance/goals/{$goal['id']}")->assertJsonPath('data.saved_cents', 0);
});

it('uses the linked savings account balance as goal progress', function () {
    $savings = F::account($this->user, ['name' => 'Ahorro', 'type' => 'savings', 'initial_balance_cents' => 50000]);

    $goal = $this->postJson('/api/v1/finance/goals', [
        'name' => 'Colchón',
        'target_cents' => 100000,
        'account_id' => $savings->id,
    ])->assertCreated()->assertJsonPath('data.saved_cents', 50000)->assertJsonPath('data.progress_bp', 5000)->json('data');

    F::transfer($this->user, $this->account, $savings, 50000, '2026-10-24');

    $this->getJson("/api/v1/finance/goals/{$goal['id']}")
        ->assertJsonPath('data.saved_cents', 100000)
        ->assertJsonPath('data.achieved', true);

    Notification::assertSentTo($this->user, GoalReached::class, fn (GoalReached $notification) => $notification->milestone === 100);

    $this->postJson("/api/v1/finance/goals/{$goal['id']}/contributions", ['amount_cents' => 100])->assertUnprocessable();
});
