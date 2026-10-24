<?php

use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\SharedExpenseShare;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Testing\TestResponse;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000]);
    $this->actingAs($this->user);
    $this->ana = $this->postJson('/api/v1/finance/contacts', ['name' => 'Ana'])->assertCreated()->json('data.id');
    $this->luis = $this->postJson('/api/v1/finance/contacts', ['name' => 'Luis'])->assertCreated()->json('data.id');
});

function sharedExpense(object $test, int $cents, array $shares): TestResponse
{
    return $test->postJson('/api/v1/finance/transactions', [
        'account_id' => $test->account->id,
        'kind' => 'expense',
        'amount_cents' => -$cents,
        'date' => '2026-10-20',
        'category_id' => F::category($test->user, 'Restaurantes')->id,
        'payee' => 'Cena',
        'shares' => $shares,
    ]);
}

it('splits equally including myself', function () {
    sharedExpense($this, 9000, ['mode' => 'equal', 'items' => [['contact_id' => $this->ana], ['contact_id' => $this->luis]]])
        ->assertCreated()
        ->assertJsonPath('data.shares.0.amount_cents', 3000)
        ->assertJsonPath('data.shares.1.amount_cents', 3000)
        ->assertJsonPath('data.own_amount_cents', -3000);

    sharedExpense($this, 1000, ['mode' => 'equal', 'items' => [['contact_id' => $this->ana], ['contact_id' => $this->luis]]])
        ->assertJsonPath('data.shares.0.amount_cents', 333)
        ->assertJsonPath('data.own_amount_cents', -334);
});

it('splits by amount and rejects shares above the expense', function () {
    sharedExpense($this, 5000, ['mode' => 'amount', 'items' => [['contact_id' => $this->ana, 'amount_cents' => 2000]]])
        ->assertCreated()
        ->assertJsonPath('data.own_amount_cents', -3000);

    sharedExpense($this, 5000, ['mode' => 'amount', 'items' => [['contact_id' => $this->ana, 'amount_cents' => 6000]]])
        ->assertUnprocessable();

    sharedExpense($this, 5000, ['mode' => 'percentage', 'items' => [['contact_id' => $this->ana, 'percentage' => 60], ['contact_id' => $this->luis, 'percentage' => 50]]])
        ->assertUnprocessable();
});

it('tracks contact balances and settles them with an income that is not counted as income', function () {
    sharedExpense($this, 8000, ['mode' => 'percentage', 'items' => [['contact_id' => $this->ana, 'percentage' => 50]]])->assertCreated();
    sharedExpense($this, 3000, ['mode' => 'amount', 'items' => [['contact_id' => $this->ana, 'amount_cents' => 1000]]])->assertCreated();

    $this->getJson("/api/v1/finance/contacts/{$this->ana}")
        ->assertJsonPath('data.balance_cents', 5000)
        ->assertJsonPath('data.shares_pending_cents', 5000)
        ->assertJsonCount(2, 'data.shares');

    $this->getJson('/api/v1/finance/contacts')->assertJsonPath('meta.owed_to_me_cents', 5000);

    $this->postJson("/api/v1/finance/contacts/{$this->ana}/settle", ['account_id' => $this->account->id])
        ->assertCreated()
        ->assertJsonPath('data.transaction.amount_cents', 5000)
        ->assertJsonPath('data.transaction.kind', 'income')
        ->assertJsonPath('data.contact.balance_cents', 0);

    expect(SharedExpenseShare::query()->whereNull('settled_at')->count())->toBe(0);

    $this->getJson('/api/v1/finance/summary')
        ->assertJsonPath('data.income_cents', 0)
        ->assertJsonPath('data.spent_cents', 4000 + 2000);

    $this->getJson("/api/v1/finance/accounts/{$this->account->id}")->assertJsonPath('data.balance_cents', 100000 - 8000 - 3000 + 5000);

    $this->postJson("/api/v1/finance/contacts/{$this->ana}/settle", ['account_id' => $this->account->id])->assertUnprocessable();
});

it('settles the whole contact balance including open debts in both directions', function () {
    sharedExpense($this, 4590, ['mode' => 'equal', 'items' => [['contact_id' => $this->luis]]])->assertCreated();
    $lent = $this->postJson('/api/v1/finance/debts', [
        'name' => 'Entradas del concierto', 'direction' => 'owed_to_me', 'contact_id' => $this->luis,
        'principal_cents' => 6000, 'start_date' => '2026-10-01',
    ])->assertCreated()->json('data.id');
    $borrowed = $this->postJson('/api/v1/finance/debts', [
        'name' => 'Taxi', 'direction' => 'i_owe', 'contact_id' => $this->luis,
        'principal_cents' => 1000, 'start_date' => '2026-10-02',
    ])->assertCreated()->json('data.id');

    $this->getJson("/api/v1/finance/contacts/{$this->luis}")->assertJsonPath('data.balance_cents', 2295 + 6000 - 1000);

    $response = $this->postJson("/api/v1/finance/contacts/{$this->luis}/settle", ['account_id' => $this->account->id])
        ->assertCreated()
        ->assertJsonPath('data.net_cents', 7295)
        ->assertJsonPath('data.transaction.amount_cents', 2295)
        ->assertJsonCount(3, 'data.transactions')
        ->assertJsonPath('data.contact.balance_cents', 0);

    expect(collect($response->json('data.transactions'))->pluck('amount_cents')->sort()->values()->all())->toBe([-1000, 2295, 6000]);
    $this->getJson("/api/v1/finance/debts/{$lent}")->assertJsonPath('data.closed', true);
    $this->getJson("/api/v1/finance/debts/{$borrowed}")->assertJsonPath('data.closed', true);

    $this->postJson("/api/v1/finance/contacts/{$this->luis}/settle", ['account_id' => $this->account->id])->assertUnprocessable();
});

it('settles a balance made only of debts', function () {
    $this->postJson('/api/v1/finance/debts', [
        'name' => 'Préstamo', 'direction' => 'i_owe', 'contact_id' => $this->ana,
        'principal_cents' => 2500, 'start_date' => '2026-10-01',
    ])->assertCreated();

    $this->postJson("/api/v1/finance/contacts/{$this->ana}/settle", ['account_id' => $this->account->id])
        ->assertCreated()
        ->assertJsonPath('data.net_cents', -2500)
        ->assertJsonPath('data.transaction.kind', 'expense')
        ->assertJsonPath('data.contact.balance_cents', 0);
});

it('keeps the split mode when the amount of a shared expense is edited', function () {
    $equal = sharedExpense($this, 8000, ['mode' => 'equal', 'items' => [['contact_id' => $this->ana]]])
        ->assertCreated()
        ->assertJsonPath('data.shares.0.mode', 'equal')
        ->json('data.id');

    $this->patchJson("/api/v1/finance/transactions/{$equal}", ['amount_cents' => -10000])
        ->assertOk()
        ->assertJsonPath('data.shares.0.amount_cents', 5000)
        ->assertJsonPath('data.own_amount_cents', -5000);

    $percentage = sharedExpense($this, 8000, ['mode' => 'percentage', 'items' => [['contact_id' => $this->ana, 'percentage' => '25'], ['contact_id' => $this->luis, 'percentage' => '12.5']]])
        ->assertCreated()
        ->assertJsonPath('data.shares.1.basis_points', 1250)
        ->json('data.id');

    $response = $this->patchJson("/api/v1/finance/transactions/{$percentage}", ['amount_cents' => -12000])->assertOk();
    expect(collect($response->json('data.shares'))->pluck('amount_cents', 'contact_id')->all())
        ->toBe([$this->ana => 3000, $this->luis => 1500]);

    $fixed = sharedExpense($this, 5000, ['mode' => 'amount', 'items' => [['contact_id' => $this->ana, 'amount_cents' => 2000]]])->json('data.id');
    $this->patchJson("/api/v1/finance/transactions/{$fixed}", ['amount_cents' => -6000])
        ->assertOk()
        ->assertJsonPath('data.shares.0.amount_cents', 2000);
    $this->patchJson("/api/v1/finance/transactions/{$fixed}", ['amount_cents' => -1500])->assertUnprocessable();
});

it('refuses to edit shares that were already settled', function () {
    $id = sharedExpense($this, 8000, ['mode' => 'equal', 'items' => [['contact_id' => $this->ana]]])->json('data.id');
    $this->postJson("/api/v1/finance/contacts/{$this->ana}/settle", ['account_id' => $this->account->id])->assertCreated();

    $this->patchJson("/api/v1/finance/transactions/{$id}", ['shares' => null])->assertUnprocessable();
    $this->deleteJson("/api/v1/finance/contacts/{$this->ana}")->assertUnprocessable();
    $this->deleteJson("/api/v1/finance/contacts/{$this->luis}")->assertNoContent();
});
