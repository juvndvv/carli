<?php

use App\Modules\Finance\BankSync\Services\BankSyncService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\RecurringNotReceived;
use App\Modules\Finance\Notifications\RecurringPending;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    EB::configure();
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-22')->setTime(7, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000]);
    $this->connection = EB::connection($this->user);
    EB::link($this->account, $this->connection, '2026-10-15');
    $this->actingAs($this->user);
});

function bankRule(object $test, array $overrides = []): RecurringRule
{
    $id = $test->postJson('/api/v1/finance/recurring-rules', array_merge([
        'account_id' => $test->account->id,
        'category_id' => F::category($test->user, 'Streaming')->id,
        'kind' => 'expense',
        'amount_cents' => 1399,
        'payee' => 'Netflix',
        'frequency' => 'monthly',
        'start_date' => '2026-10-20',
        'mode' => 'auto',
    ], $overrides))->assertCreated()->json('data.id');

    return RecurringRule::query()->findOrFail($id);
}

function syncBank(object $test, array $transactions): void
{
    EB::fakeAccountData($transactions);
    app(BankSyncService::class)->sync($test->connection->refresh());
}

function ruleTransactions(RecurringRule $rule)
{
    return Transaction::query()->where('recurring_rule_id', $rule->id)->orderBy('date')->get();
}

it('waits for the bank instead of booking occurrences on bank-linked accounts', function () {
    $rule = bankRule($this);

    $this->artisan('finance:materialize-recurring')->assertSuccessful();

    $expected = ruleTransactions($rule)->sole();
    expect($expected->status->value)->toBe('pending')
        ->and($expected->source->value)->toBe('recurring');

    $this->getJson('/api/v1/pending?type=recurring_to_confirm')->assertJsonCount(0, 'data');
});

it('turns the expected occurrence into the bank charge when it arrives', function () {
    $rule = bankRule($this);
    $this->artisan('finance:materialize-recurring')->assertSuccessful();

    syncBank($this, [EB::transaction('14.99', 'DBIT', '2026-10-21', 'ref-netflix', 'NETFLIX.COM')]);

    $transaction = ruleTransactions($rule)->sole();
    expect($transaction->source->value)->toBe('bank')
        ->and($transaction->status->value)->toBe('cleared')
        ->and($transaction->amount_cents)->toBe(-1499)
        ->and($transaction->date->toDateString())->toBe('2026-10-21')
        ->and($transaction->recurring_date->toDateString())->toBe('2026-10-20')
        ->and($transaction->external_id)->toBe('ref-netflix')
        ->and($transaction->payee)->toBe('Netflix')
        ->and($transaction->category_id)->toBe($rule->category_id)
        ->and(Transaction::query()->where('account_id', $this->account->id)->count())->toBe(1);

    syncBank($this, [EB::transaction('14.99', 'DBIT', '2026-10-21', 'ref-netflix', 'NETFLIX.COM')]);
    expect(Transaction::query()->where('account_id', $this->account->id)->count())->toBe(1);
});

it('links an early bank charge to the next occurrence and moves the rule forward', function () {
    $rule = bankRule($this, ['payee' => 'Gimnasio', 'amount_cents' => 2700, 'start_date' => '2026-10-25']);

    syncBank($this, [EB::transaction('27.00', 'DBIT', '2026-10-22', 'ref-gym', 'MELODIA FITNESS')]);

    $transaction = ruleTransactions($rule)->sole();
    expect($transaction->source->value)->toBe('bank')
        ->and($transaction->recurring_date->toDateString())->toBe('2026-10-25')
        ->and($transaction->payee)->toBe('Gimnasio')
        ->and($rule->refresh()->next_occurrence->toDateString())->toBe('2026-11-25');

    $this->travelTo(SpanishCalendar::date('2026-10-25')->setTime(7, 0));
    $this->artisan('finance:materialize-recurring')->assertSuccessful();
    expect(ruleTransactions($rule))->toHaveCount(1);
});

it('leaves unrelated charges alone', function () {
    $rule = bankRule($this);
    $this->artisan('finance:materialize-recurring')->assertSuccessful();

    syncBank($this, [
        EB::transaction('13.99', 'DBIT', '2026-10-10', 'ref-old', 'NETFLIX.COM'),
        EB::transaction('30.00', 'DBIT', '2026-10-21', 'ref-netflix-gift', 'NETFLIX.COM'),
        EB::transaction('12.00', 'DBIT', '2026-10-21', 'ref-shop', 'MERCADONA'),
    ]);

    expect(ruleTransactions($rule)->sole()->status->value)->toBe('pending')
        ->and(Transaction::query()->where('source', 'bank')->whereNull('recurring_rule_id')->count())->toBe(2);
});

it('warns when an expected charge never reaches the bank', function () {
    $rule = bankRule($this, ['mode' => 'confirm']);
    $this->artisan('finance:materialize-recurring')->assertSuccessful();
    $expected = ruleTransactions($rule)->sole();

    $this->travelTo(SpanishCalendar::date('2026-10-20')->setTime(9, 0));
    $this->artisan('finance:upcoming-charges')->assertSuccessful();
    Notification::assertNotSentTo($this->user, RecurringPending::class);

    $this->travelTo(SpanishCalendar::date('2026-10-25')->setTime(9, 0));
    $this->artisan('finance:upcoming-charges')->assertSuccessful();
    Notification::assertNotSentTo($this->user, RecurringNotReceived::class);
    $this->getJson('/api/v1/pending?type=recurring_to_confirm')->assertJsonCount(0, 'data');

    $this->travelTo(SpanishCalendar::date('2026-10-26')->setTime(9, 0));
    $this->artisan('finance:upcoming-charges')->assertSuccessful();
    Notification::assertSentTo($this->user, RecurringNotReceived::class, fn (RecurringNotReceived $notification) => $notification->title() === 'Netflix no ha entrado'
        && $notification->transactionId === $expected->id);
    $this->getJson('/api/v1/pending?type=recurring_to_confirm')
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.subtitle', 'Cuenta corriente · No ha entrado en el banco');
});
