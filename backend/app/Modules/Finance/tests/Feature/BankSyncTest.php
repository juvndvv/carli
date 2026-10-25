<?php

use App\Models\User;
use App\Modules\Finance\BankSync\Services\BankSyncService;
use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Jobs\SyncBankConnection;
use App\Modules\Finance\Models\BankConnection;
use App\Modules\Finance\Models\CategoryRule;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\BankConsentExpiring;
use App\Modules\Finance\Notifications\BankSyncFailed;
use App\Modules\Finance\Notifications\BudgetThresholdReached;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Carbon\CarbonImmutable;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Queue;

function runSync(BankConnection $connection): array
{
    return app(BankSyncService::class)->sync($connection->refresh());
}

function categoryRule(User $user, string $pattern, string $kind, string $categoryId): CategoryRule
{
    $rule = new CategoryRule(['pattern' => $pattern, 'kind' => $kind, 'category_id' => $categoryId]);
    $rule->user_id = $user->id;
    $rule->save();

    return $rule;
}

function bankRows(string $accountId): Collection
{
    return Transaction::query()->withoutGlobalScopes()->withTrashed()
        ->where('account_id', $accountId)->where('source', 'bank')
        ->orderBy('date')->orderBy('amount_cents')->get();
}

beforeEach(function () {
    EB::configure();
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000]);
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->connection = EB::connection($this->user);
    EB::link($this->account, $this->connection, '2026-10-20');
});

describe('import', function () {
    it('imports booked transactions with sign, payee, raw payload and no category', function () {
        EB::fakeAccountData([
            EB::transaction('12.34', 'DBIT', '2026-10-21', 'ref-1'),
            EB::transaction('1500.00', 'CRDT', '2026-10-22', 'ref-2', 'ACME SL'),
            EB::transaction('9.99', 'DBIT', '2026-10-23', 'ref-3', 'PENDIENTE', ['status' => 'PDNG']),
            EB::transaction('5.00', 'DBIT', '2026-10-19', 'ref-4', 'ANTERIOR'),
        ], '3487.66');

        $result = runSync($this->connection);
        $rows = bankRows($this->account->id);

        expect($result)->toBe(['imported' => 2, 'accounts' => 1])
            ->and($rows->map(fn (Transaction $t) => [$t->kind->value, $t->amount_cents, $t->payee, $t->external_id, $t->category_id])->all())->toBe([
                ['expense', -1234, 'MERCADONA', 'ref-1', null],
                ['income', 150000, 'ACME SL', 'ref-2', null],
            ])
            ->and($rows[0]->description)->toBe('COMPRA TARJETA MERCADONA')
            ->and($rows[0]->raw['entry_reference'])->toBe('ref-1')
            ->and($rows[0]->isUncategorized())->toBeTrue();

        $this->connection->refresh();
        $this->account->refresh();
        expect($this->connection->status->value)->toBe('active')
            ->and($this->connection->last_synced_at)->not->toBeNull()
            ->and($this->account->bank_balance_cents)->toBe(348766)
            ->and($this->account->bank_balance_at)->not->toBeNull();
    });

    it('is idempotent and never brings back deleted transactions', function () {
        $data = [
            EB::transaction('12.34', 'DBIT', '2026-10-21', 'ref-1'),
            EB::transaction('3.00', 'DBIT', '2026-10-22', 'ref-2', 'BAR PEPE'),
        ];
        EB::fakeAccountData($data);

        runSync($this->connection);
        bankRows($this->account->id)->firstWhere('external_id', 'ref-2')->delete();
        $second = runSync($this->connection);

        expect($second['imported'])->toBe(0)
            ->and(bankRows($this->account->id))->toHaveCount(2)
            ->and(Transaction::query()->withoutGlobalScopes()->whereNull('deleted_at')->where('external_id', 'ref-2')->exists())->toBeFalse();
    });

    it('skips movements in other currencies and keeps the sign when the bank omits the indicator', function () {
        EB::fakeAccountData([
            EB::transaction('12.34', 'DBIT', '2026-10-21', 'ref-usd', 'AMAZON US', ['transaction_amount' => ['currency' => 'USD', 'amount' => '12.34']]),
            EB::transaction('-7.50', 'DBIT', '2026-10-21', 'ref-signed', 'BAR PEPE', ['credit_debit_indicator' => null]),
            EB::transaction('20.00', 'CRDT', '2026-10-22', 'ref-in', 'BIZUM', ['credit_debit_indicator' => null]),
        ]);

        runSync($this->connection);

        expect(bankRows($this->account->id)->map(fn (Transaction $t) => [$t->external_id, $t->kind->value, $t->amount_cents])->all())->toBe([
            ['ref-signed', 'expense', -750],
            ['ref-in', 'income', 2000],
        ]);
    });

    it('builds a stable fallback id for repeated transactions without a bank id', function () {
        $coffee = EB::transaction('1.50', 'DBIT', '2026-10-22', null, 'CAFE');
        Http::fake([
            EB::BASE.'/accounts/uid-1/transactions*' => Http::sequence()
                ->push(['transactions' => [$coffee, $coffee]])
                ->push(['transactions' => [$coffee, $coffee, $coffee]]),
            EB::BASE.'/accounts/uid-1/balances' => Http::response(EB::balances('10.00')),
        ]);
        runSync($this->connection);
        $result = runSync($this->connection);

        $ids = bankRows($this->account->id)->pluck('external_id');
        expect($result['imported'])->toBe(1)
            ->and($ids)->toHaveCount(3)
            ->and($ids->unique())->toHaveCount(3)
            ->and($ids[0])->toBe(hash('sha256', '2026-10-22|-150|COMPRA TARJETA CAFE|0'));
    });

    it('fetches from the last booking date minus five days but never before the import date', function () {
        EB::fakeAccountData([EB::transaction('12.34', 'DBIT', '2026-10-23', 'ref-1')]);
        runSync($this->connection);
        Http::assertSent(fn (Request $request) => str_contains($request->url(), '/transactions') && $request['date_from'] === '2026-10-20');

        $this->account->forceFill(['sync_from_date' => '2026-10-01'])->save();
        runSync($this->connection);
        Http::assertSent(fn (Request $request) => str_contains($request->url(), '/transactions') && $request['date_from'] === '2026-10-18' && $request['date_to'] === '2026-10-24');
    });

    it('does not open a period for imported income until payroll is assigned', function () {
        $this->travelTo(SpanishCalendar::date('2026-10-28')->setTime(12, 0));
        EB::fakeAccountData([EB::transaction('2500.00', 'CRDT', '2026-10-28', 'nomina', 'EMPRESA SA')]);
        runSync($this->connection);
        $income = bankRows($this->account->id)->first();

        expect(Period::query()->ownedBy($this->user)->where('opening_transaction_id', $income->id)->exists())->toBeFalse();

        $this->actingAs($this->user)->patchJson("/api/v1/finance/transactions/{$income->id}", [
            'category_id' => F::category($this->user, 'Nómina')->id,
        ])->assertOk();

        expect(app(PeriodService::class)->current($this->user)->opening_transaction_id)->toBe($income->id);
    });

    it('marks the connection as failing and notifies once', function () {
        Http::fake([EB::BASE.'/accounts/uid-1/transactions*' => Http::response(['message' => 'ASPSP error'], 500)]);

        runSync($this->connection);
        runSync($this->connection);

        $this->connection->refresh();
        expect($this->connection->status->value)->toBe('error')
            ->and($this->connection->last_error)->toContain('HTTP 500');
        Notification::assertSentToTimes($this->user, BankSyncFailed::class, 1);
    });

    it('recovers from an error on the next successful sync', function () {
        $this->connection->forceFill(['status' => 'error', 'last_error' => 'boom'])->save();
        EB::fakeAccountData([]);

        runSync($this->connection);

        expect($this->connection->refresh()->status->value)->toBe('active')
            ->and($this->connection->last_error)->toBeNull();
    });

    it('marks expired connections without calling the bank', function () {
        Http::fake();
        $this->connection->forceFill(['valid_until' => CarbonImmutable::now()->subMinute()])->save();

        runSync($this->connection);

        expect($this->connection->refresh()->status->value)->toBe('expired');
        Http::assertNothingSent();
    });
});

describe('autocategorization', function () {
    it('categorizes matching imports so they skip pending', function () {
        categoryRule($this->user, 'MERCADONA', 'expense', F::category($this->user, 'Supermercado')->id);
        categoryRule($this->user, 'EMPRESA', 'income', F::category($this->user, 'Nómina')->id);
        EB::fakeAccountData([
            EB::transaction('12.34', 'DBIT', '2026-10-21', 'ref-1', 'Mercadona Valencia'),
            EB::transaction('8.00', 'DBIT', '2026-10-21', 'ref-2', 'BAR PEPE'),
            EB::transaction('2500.00', 'CRDT', '2026-10-22', 'ref-3', 'EMPRESA SA'),
        ]);

        runSync($this->connection);
        $rows = bankRows($this->account->id)->keyBy('external_id');

        expect($rows['ref-1']->category_id)->toBe(F::category($this->user, 'Supermercado')->id)
            ->and($rows['ref-2']->category_id)->toBeNull()
            ->and($rows['ref-3']->category_id)->toBeNull();

        $this->actingAs($this->user)->getJson('/api/v1/pending/summary')->assertJsonPath('data.total', 2);
    });

    it('evaluates budget alerts once per sync instead of per row', function () {
        $supermarket = F::category($this->user, 'Supermercado');
        app(BudgetService::class)->upsert(app(PeriodService::class)->current($this->user), [['category_id' => $supermarket->id, 'amount_cents' => 10000]]);
        categoryRule($this->user, 'MERCADONA', 'expense', $supermarket->id);
        EB::fakeAccountData([
            EB::transaction('85.00', 'DBIT', '2026-10-21', 'ref-1'),
            EB::transaction('20.00', 'DBIT', '2026-10-22', 'ref-2'),
            EB::transaction('10.00', 'DBIT', '2026-10-23', 'ref-3'),
        ]);

        runSync($this->connection);

        Notification::assertSentToTimes($this->user, BudgetThresholdReached::class, 1);
        Notification::assertSentTo($this->user, BudgetThresholdReached::class, fn (BudgetThresholdReached $n) => $n->threshold === 100);
    });
});

describe('jobs', function () {
    it('queues one sync per active or failing connection', function () {
        Queue::fake();
        EB::connection($this->user, ['status' => 'error']);
        EB::connection($this->user, ['status' => 'revoked', 'session_id' => null]);
        EB::connection($this->user, ['status' => 'expired']);

        $this->artisan('finance:bank-sync')->assertSuccessful();

        Queue::assertPushed(SyncBankConnection::class, 2);
    });

    it('runs the sync job for a connection', function () {
        EB::fakeAccountData([EB::transaction('12.34', 'DBIT', '2026-10-21', 'ref-1')]);

        (new SyncBankConnection($this->connection->id, '203.0.113.5', 'Firefox'))->handle(app(BankSyncService::class));

        expect(bankRows($this->account->id))->toHaveCount(1);
        Http::assertSent(fn (Request $request) => $request->hasHeader('Psu-Ip-Address', '203.0.113.5'));
    });

    it('warns 7 and 1 days before the consent expires and then marks it expired', function () {
        $this->connection->forceFill(['valid_until' => SpanishCalendar::date('2026-10-31')->setTime(10, 0)])->save();

        $this->artisan('finance:bank-consent-expiry')->assertSuccessful();
        $this->artisan('finance:bank-consent-expiry')->assertSuccessful();
        Notification::assertSentToTimes($this->user, BankConsentExpiring::class, 1);

        $this->travelTo(SpanishCalendar::date('2026-10-28')->setTime(9, 0));
        $this->artisan('finance:bank-consent-expiry')->assertSuccessful();
        Notification::assertSentToTimes($this->user, BankConsentExpiring::class, 1);

        $this->travelTo(SpanishCalendar::date('2026-10-30')->setTime(9, 0));
        $this->artisan('finance:bank-consent-expiry')->assertSuccessful();
        Notification::assertSentToTimes($this->user, BankConsentExpiring::class, 2);
        Notification::assertSentTo($this->user, BankConsentExpiring::class, fn (BankConsentExpiring $n) => $n->daysLeft === 1 && $n->title() === 'La conexión con BBVA caduca mañana');

        $this->travelTo(SpanishCalendar::date('2026-10-31')->setTime(11, 0));
        $this->artisan('finance:bank-consent-expiry')->assertSuccessful();
        expect($this->connection->refresh()->status->value)->toBe('expired');
    });

    it('schedules the bank jobs in Madrid time', function () {
        $events = collect(app(Schedule::class)->events())->mapWithKeys(fn ($event) => [trim(str($event->command)->after('artisan')->replace("'", '')->toString()) => $event]);

        expect($events['finance:bank-sync']->expression)->toBe('0 7,13,19 * * *')
            ->and($events['finance:bank-sync']->timezone)->toBe('Europe/Madrid')
            ->and($events['finance:bank-consent-expiry']->expression)->toBe('0 9 * * *');
    });
});
