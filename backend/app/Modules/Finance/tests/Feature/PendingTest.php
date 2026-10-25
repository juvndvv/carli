<?php

use App\Core\Pending\PendingDigestNotification;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000]);
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->actingAs($this->user);
});

function bankExpense(object $test, int $cents, string $date, string $payee, ?Account $account = null): Transaction
{
    return app(TransactionService::class)->create($test->user, [
        'account_id' => ($account ?? $test->account)->id,
        'kind' => 'expense',
        'amount_cents' => -abs($cents),
        'date' => $date,
        'payee' => $payee,
    ], source: TransactionSource::Bank);
}

function confirmRule(object $test): string
{
    $rule = $test->postJson('/api/v1/finance/recurring-rules', [
        'account_id' => $test->account->id,
        'category_id' => F::category($test->user, 'Streaming')->id,
        'kind' => 'expense',
        'amount_cents' => 1399,
        'payee' => 'Netflix',
        'frequency' => 'monthly',
        'start_date' => '2026-10-20',
        'mode' => 'confirm',
    ])->assertCreated()->json('data.id');

    $test->artisan('finance:materialize-recurring')->assertSuccessful();

    return $rule;
}

describe('pending items', function () {
    it('lists uncategorized income and expenses, newest first', function () {
        $older = bankExpense($this, 1250, '2026-10-10', 'MERCADONA');
        $newer = bankExpense($this, 900, '2026-10-20', 'BAR PEPE');
        F::expense($this->user, $this->account, 500, '2026-10-21');
        F::transfer($this->user, $this->account, F::account($this->user, ['name' => 'Ahorro', 'type' => 'savings']), 1000, '2026-10-21');
        bankExpense($this, 300, '2026-10-22', 'BORRADO')->delete();

        $this->getJson('/api/v1/pending/summary')
            ->assertOk()
            ->assertJsonPath('data.total', 2)
            ->assertJsonPath('data.by_module', [
                ['module' => 'finance', 'module_name' => 'Finanzas', 'type' => 'uncategorized_transaction', 'count' => 2],
            ]);

        $this->getJson('/api/v1/pending?module=finance&type=uncategorized_transaction')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0', [
                'module' => 'finance',
                'type' => 'uncategorized_transaction',
                'id' => $newer->id,
                'title' => 'BAR PEPE',
                'subtitle' => 'Cuenta corriente · Importado del banco',
                'amount_cents' => -900,
                'date' => '2026-10-20',
                'route' => '/finanzas/movimientos?sin_categoria=1&periodo=todos',
                'meta' => [
                    'transaction_id' => $newer->id,
                    'kind' => 'expense',
                    'account_id' => $this->account->id,
                    'source' => 'bank',
                    'payee' => 'BAR PEPE',
                    'description' => null,
                ],
            ])
            ->assertJsonPath('data.1.id', $older->id);
    });

    it('does not ask to categorize splits, debt payments or settlements', function () {
        F::expense($this->user, $this->account, 1000, '2026-10-20', null, ['splits' => [
            ['category_id' => F::category($this->user, 'Supermercado')->id, 'amount_cents' => -600],
            ['category_id' => F::category($this->user, 'Ropa')->id, 'amount_cents' => -400],
        ]]);

        $ana = $this->postJson('/api/v1/finance/contacts', ['name' => 'Ana'])->json('data.id');
        $debt = $this->postJson('/api/v1/finance/debts', [
            'name' => 'Préstamo de Ana', 'direction' => 'i_owe', 'contact_id' => $ana,
            'principal_cents' => 30000, 'start_date' => '2026-10-01',
        ])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/debts/{$debt}/payments", ['account_id' => $this->account->id, 'amount_cents' => 10000])->assertCreated();

        $this->postJson('/api/v1/finance/transactions', [
            'account_id' => $this->account->id, 'kind' => 'expense', 'amount_cents' => -8000, 'date' => '2026-10-20',
            'category_id' => F::category($this->user, 'Restaurantes')->id,
            'shares' => ['mode' => 'equal', 'items' => [['contact_id' => $ana]]],
        ])->assertCreated();
        $this->postJson("/api/v1/finance/contacts/{$ana}/settle", ['account_id' => $this->account->id])->assertCreated();

        $this->getJson('/api/v1/pending/summary')->assertJsonPath('data.total', 0);
        $this->getJson('/api/v1/pending')->assertJsonCount(0, 'data');
    });

    it('lists recurring occurrences waiting for confirmation', function () {
        Notification::fake();
        $rule = confirmRule($this);
        $pending = Transaction::query()->where('recurring_rule_id', $rule)->firstOrFail();

        $this->getJson('/api/v1/pending/summary')->assertJsonPath('data.by_module', [
            ['module' => 'finance', 'module_name' => 'Finanzas', 'type' => 'recurring_to_confirm', 'count' => 1],
        ]);

        $this->getJson('/api/v1/pending?type=recurring_to_confirm')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $pending->id)
            ->assertJsonPath('data.0.title', 'Netflix')
            ->assertJsonPath('data.0.subtitle', 'Cuenta corriente · Por confirmar')
            ->assertJsonPath('data.0.amount_cents', -1399)
            ->assertJsonPath('data.0.route', '/finanzas/recurrentes')
            ->assertJsonPath('data.0.meta.rule_id', $rule);

        $this->postJson("/api/v1/finance/recurring-rules/{$rule}/confirm")->assertOk();

        $this->getJson('/api/v1/pending/summary')->assertJsonPath('data.total', 0);
    });

    it('drops an item as soon as it gets a category', function () {
        $transaction = bankExpense($this, 1250, '2026-10-10', 'MERCADONA');

        $this->patchJson("/api/v1/finance/transactions/{$transaction->id}", ['category_id' => F::category($this->user, 'Supermercado')->id])
            ->assertOk()
            ->assertJsonPath('data.uncategorized', false);

        $this->getJson('/api/v1/pending/summary')->assertJsonPath('data.total', 0);
    });

    it('pages through both types with a cursor', function () {
        Notification::fake();
        foreach (range(1, 51) as $day) {
            bankExpense($this, 100 + $day, '2026-10-'.str_pad((string) (($day % 23) + 1), 2, '0', STR_PAD_LEFT), "COMPRA {$day}");
        }
        confirmRule($this);

        $ids = [];
        $types = [];
        $cursor = '';
        do {
            $page = $this->getJson('/api/v1/pending'.($cursor === '' ? '' : '?cursor='.$cursor))->assertOk();
            $ids = [...$ids, ...collect($page->json('data'))->pluck('id')->all()];
            $types = [...$types, ...collect($page->json('data'))->pluck('type')->all()];
            $cursor = (string) $page->json('meta.next_cursor');
        } while ($cursor !== '');

        expect($ids)->toHaveCount(52)
            ->and(array_unique($ids))->toHaveCount(52)
            ->and(array_count_values($types))->toBe(['uncategorized_transaction' => 51, 'recurring_to_confirm' => 1]);
    });

    it('hides finance items when the module is disabled', function () {
        bankExpense($this, 1250, '2026-10-10', 'MERCADONA');
        $this->user->moduleSettings()->create(['module_id' => 'finance', 'enabled' => false]);

        $this->getJson('/api/v1/pending/summary')->assertExactJson(['data' => ['total' => 0, 'by_module' => []]]);
    });

    it('summarizes finance items in the daily digest', function () {
        Notification::fake();
        bankExpense($this, 1250, '2026-10-10', 'MERCADONA');
        bankExpense($this, 900, '2026-10-11', 'BAR PEPE');
        confirmRule($this);

        $this->artisan('core:pending-digest')->assertSuccessful();

        Notification::assertSentTo($this->user, PendingDigestNotification::class, fn (PendingDigestNotification $notification) => $notification->body() === 'Tienes 2 movimientos por categorizar y 1 recurrente por confirmar');
    });
});

describe('transaction source', function () {
    it('marks manual, recurring and bank transactions', function () {
        Notification::fake();
        $manual = F::expense($this->user, $this->account, 500, '2026-10-21');
        $rule = confirmRule($this);
        $bank = bankExpense($this, 1250, '2026-10-10', 'MERCADONA');

        expect($manual->source)->toBe(TransactionSource::Manual)
            ->and(Transaction::query()->where('recurring_rule_id', $rule)->firstOrFail()->source)->toBe(TransactionSource::Recurring)
            ->and($bank->source)->toBe(TransactionSource::Bank);

        $this->getJson("/api/v1/finance/transactions/{$bank->id}")
            ->assertJsonPath('data.source', 'bank')
            ->assertJsonPath('data.uncategorized', true);
    });

    it('requires a category for manual income and expenses', function () {
        $this->postJson('/api/v1/finance/transactions', [
            'account_id' => $this->account->id, 'kind' => 'expense', 'amount_cents' => -500, 'date' => '2026-10-21',
        ])->assertUnprocessable()->assertJsonValidationErrors(['category_id' => 'Elige una categoría.']);

        $this->postJson('/api/v1/finance/transactions', [
            'account_id' => $this->account->id, 'kind' => 'income', 'amount_cents' => 500, 'date' => '2026-10-21', 'category_id' => null,
        ])->assertUnprocessable()->assertJsonValidationErrors('category_id');

        $this->postJson('/api/v1/finance/transactions', [
            'account_id' => $this->account->id, 'kind' => 'adjustment', 'amount_cents' => 500, 'date' => '2026-10-21',
        ])->assertCreated()->assertJsonPath('data.source', 'manual');
    });

    it('does not let clients mark a transaction as imported', function () {
        $this->postJson('/api/v1/finance/transactions', [
            'account_id' => $this->account->id, 'kind' => 'expense', 'amount_cents' => -500, 'date' => '2026-10-21',
            'category_id' => F::category($this->user, 'Supermercado')->id, 'source' => 'bank',
        ])->assertUnprocessable()->assertJsonValidationErrors('source');

        $manual = F::expense($this->user, $this->account, 500, '2026-10-21');
        $this->patchJson("/api/v1/finance/transactions/{$manual->id}", ['source' => 'bank'])->assertUnprocessable();

        expect($manual->refresh()->source)->toBe(TransactionSource::Manual);
    });

    it('only lets imported transactions lose their category', function () {
        $manual = F::expense($this->user, $this->account, 500, '2026-10-21');
        $this->patchJson("/api/v1/finance/transactions/{$manual->id}", ['category_id' => null])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('category_id');

        $bank = bankExpense($this, 1250, '2026-10-10', 'MERCADONA');
        $this->patchJson("/api/v1/finance/transactions/{$bank->id}", ['notes' => 'Revisar', 'category_id' => null])->assertOk();
    });

    it('keeps the bank data of imported transactions untouchable', function () {
        $bank = bankExpense($this, 1250, '2026-10-10', 'MERCADONA');
        $other = F::account($this->user, ['name' => 'Efectivo']);

        $this->patchJson("/api/v1/finance/transactions/{$bank->id}", [
            'account_id' => $other->id, 'kind' => 'income', 'amount_cents' => 1250, 'date' => '2026-12-01',
        ])->assertUnprocessable()->assertJsonValidationErrors(['account_id', 'kind', 'amount_cents', 'date']);

        $this->patchJson("/api/v1/finance/transactions/{$bank->id}", [
            'account_id' => $this->account->id, 'kind' => 'expense', 'amount_cents' => -1250, 'date' => '2026-10-10',
            'category_id' => F::category($this->user, 'Supermercado')->id, 'notes' => 'Compra semanal',
        ])->assertOk()->assertJsonPath('data.notes', 'Compra semanal');

        $manual = F::expense($this->user, $this->account, 500, '2026-10-21');
        $this->patchJson('/api/v1/finance/transactions/bulk', ['ids' => [$bank->id, $manual->id], 'account_id' => $other->id])
            ->assertOk()->assertJsonPath('data.updated', 2);

        expect($bank->refresh()->account_id)->toBe($this->account->id)
            ->and($manual->refresh()->account_id)->toBe($other->id);
    });

    it('filters transactions by source and by missing category', function () {
        Notification::fake();
        F::expense($this->user, $this->account, 500, '2026-10-21');
        $bank = bankExpense($this, 1250, '2026-10-10', 'MERCADONA');
        $categorized = bankExpense($this, 700, '2026-10-11', 'ZARA');
        $this->patchJson("/api/v1/finance/transactions/{$categorized->id}", ['category_id' => F::category($this->user, 'Ropa')->id])->assertOk();
        confirmRule($this);

        $this->getJson('/api/v1/finance/transactions?source=bank')->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/finance/transactions?source=recurring')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/finance/transactions?uncategorized=1')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $bank->id);
        $this->getJson('/api/v1/finance/transactions?source=robot')->assertUnprocessable();
    });
});

describe('uncategorized spending', function () {
    it('shows the uncategorized expense of the period in dashboard and budgets', function () {
        bankExpense($this, 1250, '2026-10-10', 'MERCADONA');
        bankExpense($this, 750, '2026-10-12', 'BAR PEPE');
        bankExpense($this, 9900, '2026-09-01', 'ANTERIOR');
        app(TransactionService::class)->create($this->user, [
            'account_id' => $this->account->id, 'kind' => 'income', 'amount_cents' => 3000, 'date' => '2026-10-12', 'payee' => 'BIZUM',
        ], source: TransactionSource::Bank);
        F::expense($this->user, $this->account, 500, '2026-10-21');

        $this->getJson('/api/v1/finance/dashboard')
            ->assertOk()
            ->assertJsonPath('data.uncategorized', ['expense_cents' => 2000, 'count' => 2]);

        $this->getJson('/api/v1/finance/budgets')
            ->assertOk()
            ->assertJsonPath('meta.uncategorized', ['expense_cents' => 2000, 'count' => 2]);
    });
});
