<?php

use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\ShareSettlement;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000]);
    $this->actingAs($this->user);
    $this->ana = $this->postJson('/api/v1/finance/contacts', ['name' => 'Ana'])->assertCreated()->json('data.id');
    $this->luis = $this->postJson('/api/v1/finance/contacts', ['name' => 'Luis'])->assertCreated()->json('data.id');
});

function dinner(object $test, int $cents, ?array $shares = null): string
{
    return $test->postJson('/api/v1/finance/transactions', array_filter([
        'account_id' => $test->account->id,
        'kind' => 'expense',
        'amount_cents' => -$cents,
        'date' => '2026-10-20',
        'category_id' => F::category($test->user, 'Restaurantes')->id,
        'payee' => 'Cena',
        'shares' => $shares,
    ]))->assertCreated()->json('data.id');
}

function bizum(object $test, int $cents, string $date = '2026-10-21'): string
{
    $income = new Transaction([
        'account_id' => $test->account->id,
        'kind' => 'income',
        'amount_cents' => $cents,
        'date' => $date,
        'payee' => 'BIZUM',
        'source' => 'bank',
        'external_id' => 'bizum-'.uniqid(),
    ]);
    $income->user_id = $test->user->id;
    $income->save();

    return $income->id;
}

it('turns several bizums into the share of an expense that had none, so they are neither income nor spending', function () {
    $expense = dinner($this, 9000);
    $first = bizum($this, 3000);
    $second = bizum($this, 3000, '2026-10-22');

    $this->getJson('/api/v1/finance/summary')
        ->assertJsonPath('data.income_cents', 6000)
        ->assertJsonPath('data.spent_cents', 9000);

    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->ana, 'income_ids' => [$first, $second]])
        ->assertCreated()
        ->assertJsonPath('data.expense.own_amount_cents', -3000)
        ->assertJsonPath('data.expense.shares.0.amount_cents', 6000)
        ->assertJsonPath('data.expense.shares.0.settled', true)
        ->assertJsonPath('data.expense.shares.0.settled_cents', 6000)
        ->assertJsonPath('data.incomes.0.reimbursed_cents', 3000)
        ->assertJsonPath('data.incomes.0.own_amount_cents', 0)
        ->assertJsonPath('data.incomes.0.uncategorized', false)
        ->assertJsonPath('data.incomes.0.reimburses.0.name', 'Ana');

    $this->getJson('/api/v1/finance/summary')
        ->assertJsonPath('data.income_cents', 0)
        ->assertJsonPath('data.spent_cents', 3000);

    $this->getJson("/api/v1/finance/contacts/{$this->ana}")->assertJsonPath('data.balance_cents', 0);
    $this->getJson("/api/v1/finance/accounts/{$this->account->id}")->assertJsonPath('data.balance_cents', 100000 - 9000 + 6000);
});

it('pays an existing share partly and keeps the rest pending', function () {
    $expense = dinner($this, 9000, ['mode' => 'equal', 'items' => [['contact_id' => $this->ana], ['contact_id' => $this->luis]]]);
    $bizum = bizum($this, 1000);

    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->ana, 'income_ids' => [$bizum]])
        ->assertCreated()
        ->assertJsonPath('data.expense.own_amount_cents', -3000)
        ->assertJsonPath('data.expense.shares.0.settled', false)
        ->assertJsonPath('data.expense.shares.0.settled_cents', 1000);

    $this->getJson("/api/v1/finance/contacts/{$this->ana}")->assertJsonPath('data.balance_cents', 2000);

    // Shares that already received money cannot be redistributed.
    $this->patchJson("/api/v1/finance/transactions/{$expense}", ['shares' => null])->assertUnprocessable();
    $this->deleteJson("/api/v1/finance/transactions/{$expense}")->assertUnprocessable();
});

it('grows the share into my part when the bizum is larger, and leaves what exceeds the expense as income', function () {
    $expense = dinner($this, 5000, ['mode' => 'amount', 'items' => [['contact_id' => $this->ana, 'amount_cents' => 2000]]]);
    $bizum = bizum($this, 7000);

    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->ana, 'income_ids' => [$bizum]])
        ->assertCreated()
        ->assertJsonPath('data.expense.shares.0.amount_cents', 5000)
        ->assertJsonPath('data.expense.own_amount_cents', 0)
        ->assertJsonPath('data.incomes.0.reimbursed_cents', 5000)
        ->assertJsonPath('data.incomes.0.own_amount_cents', 2000);

    $this->getJson('/api/v1/finance/summary')
        ->assertJsonPath('data.income_cents', 2000)
        ->assertJsonPath('data.spent_cents', 0);

    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->luis, 'income_ids' => [bizum($this, 500)]])
        ->assertUnprocessable();
});

it('settles a contact with bizums already imported instead of creating an income', function () {
    dinner($this, 8000, ['mode' => 'percentage', 'items' => [['contact_id' => $this->ana, 'percentage' => 50]]]);
    dinner($this, 3000, ['mode' => 'amount', 'items' => [['contact_id' => $this->ana, 'amount_cents' => 1000]]]);
    $bizums = [bizum($this, 2500), bizum($this, 2500)];
    $before = Transaction::query()->count();

    $this->getJson("/api/v1/finance/reimbursements/candidates?contact_id={$this->ana}")
        ->assertOk()
        ->assertJsonCount(2, 'data');

    $this->postJson("/api/v1/finance/contacts/{$this->ana}/settle", ['income_ids' => $bizums])
        ->assertOk()
        ->assertJsonPath('data.net_cents', 0)
        ->assertJsonPath('data.contact.balance_cents', 0);

    expect(Transaction::query()->count())->toBe($before);
    $this->getJson('/api/v1/finance/summary')
        ->assertJsonPath('data.income_cents', 0)
        ->assertJsonPath('data.spent_cents', 4000 + 2000);

    $this->getJson("/api/v1/finance/reimbursements/candidates?contact_id={$this->ana}")->assertJsonCount(0, 'data');
});

it('undoes a reimbursement and removes the share it created', function () {
    $expense = dinner($this, 9000);
    $bizum = bizum($this, 3000);

    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->ana, 'income_ids' => [$bizum]])->assertCreated();

    $this->deleteJson("/api/v1/finance/transactions/{$bizum}/reimbursements")
        ->assertOk()
        ->assertJsonPath('data.reimbursed_cents', 0)
        ->assertJsonPath('data.uncategorized', true);

    $this->getJson("/api/v1/finance/transactions/{$expense}")
        ->assertJsonCount(0, 'data.shares')
        ->assertJsonPath('data.own_amount_cents', -9000);
    expect(ShareSettlement::query()->count())->toBe(0);
});

it('reopens the share when the reimbursing income is deleted', function () {
    $expense = dinner($this, 8000, ['mode' => 'equal', 'items' => [['contact_id' => $this->ana]]]);
    $bizum = bizum($this, 4000);

    $this->postJson("/api/v1/finance/contacts/{$this->ana}/settle", ['income_ids' => [$bizum]])->assertOk();
    $this->deleteJson("/api/v1/finance/transactions/{$bizum}")->assertSuccessful();

    $this->getJson("/api/v1/finance/transactions/{$expense}")
        ->assertJsonPath('data.shares.0.settled', false)
        ->assertJsonPath('data.shares.0.amount_cents', 4000);
    $this->getJson("/api/v1/finance/contacts/{$this->ana}")->assertJsonPath('data.balance_cents', 4000);
});

it('only links incomes and does not reuse what is already linked', function () {
    $expense = dinner($this, 9000);
    $other = dinner($this, 1000);
    $bizum = bizum($this, 3000);

    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->ana, 'income_ids' => [$other]])->assertUnprocessable();
    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $bizum, 'contact_id' => $this->ana, 'income_ids' => [$bizum]])->assertUnprocessable();
    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->ana, 'income_ids' => [$bizum]])->assertCreated();
    $this->postJson('/api/v1/finance/reimbursements', ['expense_id' => $expense, 'contact_id' => $this->luis, 'income_ids' => [$bizum]])->assertUnprocessable();

    $this->getJson("/api/v1/finance/reimbursements/candidates?expense_id={$expense}")->assertJsonCount(0, 'data');
    $this->getJson("/api/v1/finance/reimbursements/candidates?income_id={$bizum}")->assertJsonCount(2, 'data');
});
