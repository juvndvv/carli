<?php

use App\Core\Search\ModuleSearcher;
use App\Models\User;
use App\Modules\Finance\database\seeders\FinanceDemoSeeder;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Budget;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\SavingsGoal;
use App\Modules\Finance\Models\SharedExpenseShare;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Search\FinanceSearcher;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
});

it('reads and updates finance settings', function () {
    $user = F::user();
    $account = F::account($user);
    $this->actingAs($user);

    $this->getJson('/api/v1/finance/settings')
        ->assertOk()
        ->assertExactJson(['data' => [
            'default_account_id' => null,
            'last_used_account_id' => null,
            'budget_warning_threshold' => 80,
            'period_min_days' => 20,
            'period_mode' => 'payroll',
            'remind_days_before' => 2,
        ]]);

    F::expense($user, $account, 100, '2026-10-24');

    $this->putJson('/api/v1/finance/settings', ['default_account_id' => $account->id, 'budget_warning_threshold' => 90, 'remind_days_before' => 3])
        ->assertOk()
        ->assertJsonPath('data.default_account_id', $account->id)
        ->assertJsonPath('data.last_used_account_id', $account->id)
        ->assertJsonPath('data.budget_warning_threshold', 90)
        ->assertJsonPath('meta.periods_changed', false);

    $this->putJson('/api/v1/finance/settings', ['period_mode' => 'weekly', 'budget_warning_threshold' => 0])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['period_mode', 'budget_warning_threshold']);
});

it('registers a global search provider', function () {
    $user = F::user();
    $account = F::account($user, ['name' => 'Cuenta Mercado']);
    F::expense($user, $account, 4250, '2026-10-23', 'Supermercado', ['payee' => 'Mercadona']);

    $searchers = collect(app()->tagged(ModuleSearcher::TAG))->filter(fn ($searcher) => $searcher instanceof FinanceSearcher);
    expect($searchers)->toHaveCount(1);

    $results = app(FinanceSearcher::class)->search($user, 'merca', 10);
    expect(array_map(fn ($result) => $result->type, $results))->toBe(['account', 'transaction'])
        ->and($results[1]->subtitle)->toBe('-42,50 € · 23 oct · Supermercado')
        ->and($results[0]->url)->toBe('/finanzas/cuentas/'.$account->id);

    expect(app(FinanceSearcher::class)->search(F::user(), 'merca', 10))->toBe([]);
});

it('exposes the module manifest next to the provider', function () {
    $manifest = require app_path('Modules/Finance/module.php');

    expect($manifest['id'])->toBe('finance')
        ->and($manifest['route'])->toBe('/finanzas')
        ->and(array_keys($manifest['notifications']))->toBe(['budget_threshold', 'upcoming_charge', 'recurring_pending', 'goal_reached', 'debt_reminder', 'payroll_overdue', 'weekly_summary', 'bank_consent_expiring', 'bank_sync_failed'])
        ->and($manifest['notifications']['weekly_summary']['push'])->toBeFalse();
});

it('seeds realistic demo data for the demo user', function () {
    Notification::fake();
    $user = User::factory()->create(['email' => FinanceDemoSeeder::DEMO_EMAIL]);

    $this->seed(FinanceDemoSeeder::class);
    $this->seed(FinanceDemoSeeder::class);

    expect(Account::query()->ownedBy($user)->count())->toBe(4)
        ->and(Account::query()->ownedBy($user)->where('type', 'credit_card')->exists())->toBeTrue()
        ->and(Transaction::query()->ownedBy($user)->count())->toBeGreaterThan(80)
        ->and(Period::query()->ownedBy($user)->count())->toBe(3)
        ->and(Period::query()->ownedBy($user)->whereNull('end_date')->first()?->start_date->toDateString())->toBe('2026-09-28')
        ->and(Budget::query()->ownedBy($user)->count())->toBeGreaterThan(0)
        ->and(RecurringRule::query()->ownedBy($user)->where('is_subscription', true)->count())->toBe(4)
        ->and(SavingsGoal::query()->ownedBy($user)->count())->toBe(2)
        ->and(Debt::query()->ownedBy($user)->count())->toBe(2)
        ->and(SharedExpenseShare::query()->whereNull('settled_at')->count())->toBeGreaterThan(0)
        ->and(Transaction::query()->ownedBy($user)->where('status', 'pending')->count())->toBe(1);

    $this->actingAs($user)->getJson('/api/v1/finance/dashboard')->assertOk();
});
