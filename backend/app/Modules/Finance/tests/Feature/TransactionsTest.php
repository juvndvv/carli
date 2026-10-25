<?php

use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Tag;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\DB;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user, ['initial_balance_cents' => 100000]);
    $this->actingAs($this->user);
});

it('creates a transaction with the documented JSON shape', function () {
    $category = F::category($this->user, 'Supermercado');

    $this->postJson('/api/v1/finance/transactions', [
        'account_id' => $this->account->id,
        'kind' => 'expense',
        'amount_cents' => -4250,
        'date' => '2026-10-23',
        'category_id' => $category->id,
        'payee' => 'Mercadona',
        'tags' => ['Casa', '#casa'],
    ])->assertCreated()
        ->assertJsonPath('data.kind', 'expense')
        ->assertJsonPath('data.amount_cents', -4250)
        ->assertJsonPath('data.own_amount_cents', -4250)
        ->assertJsonPath('data.date', '2026-10-23')
        ->assertJsonPath('data.category.name', 'Supermercado')
        ->assertJsonPath('data.category.parent', 'Alimentación')
        ->assertJsonPath('data.category.icon', 'shopping-cart')
        ->assertJsonPath('data.payee', 'Mercadona')
        ->assertJsonPath('data.tags', ['casa'])
        ->assertJsonPath('data.status', 'cleared')
        ->assertJsonPath('data.shares', [])
        ->assertJsonPath('meta.periods_changed', true);
});

it('validates amount sign and category kind', function () {
    $this->postJson('/api/v1/finance/transactions', [
        'account_id' => $this->account->id,
        'kind' => 'expense',
        'amount_cents' => 4250,
        'date' => '2026-10-23',
        'category_id' => F::category($this->user, 'Supermercado')->id,
    ])->assertUnprocessable()->assertJsonValidationErrors('amount_cents');

    $this->postJson('/api/v1/finance/transactions', [
        'account_id' => $this->account->id,
        'kind' => 'expense',
        'amount_cents' => -4250,
        'date' => '2026-10-23',
        'category_id' => F::category($this->user, 'Nómina')->id,
    ])->assertUnprocessable()->assertJsonValidationErrors('category_id');

    $this->postJson('/api/v1/finance/transactions', [
        'account_id' => 'not-a-uuid',
        'kind' => 'transfer',
        'amount_cents' => 0,
        'date' => '23/10/2026',
    ])->assertUnprocessable()->assertJsonValidationErrors(['account_id', 'kind', 'amount_cents', 'date']);
});

it('updates, deletes and restores a transaction', function () {
    $transaction = F::expense($this->user, $this->account, 1000, '2026-10-20');

    $this->patchJson("/api/v1/finance/transactions/{$transaction->id}", [
        'amount_cents' => -1500,
        'notes' => 'Con descuento',
        'category_id' => F::category($this->user, 'Restaurantes')->id,
    ])->assertOk()
        ->assertJsonPath('data.amount_cents', -1500)
        ->assertJsonPath('data.notes', 'Con descuento')
        ->assertJsonPath('data.category.name', 'Restaurantes');

    $this->deleteJson("/api/v1/finance/transactions/{$transaction->id}")->assertOk();
    $this->getJson("/api/v1/finance/transactions/{$transaction->id}")->assertNotFound();
    $this->getJson("/api/v1/finance/accounts/{$this->account->id}")->assertJsonPath('data.balance_cents', 100000);

    $this->postJson("/api/v1/finance/transactions/{$transaction->id}/restore")->assertOk()->assertJsonPath('data.deleted', false);
    $this->getJson("/api/v1/finance/accounts/{$this->account->id}")->assertJsonPath('data.balance_cents', 98500);
});

it('splits a transaction across categories', function () {
    $response = $this->postJson('/api/v1/finance/transactions', [
        'account_id' => $this->account->id,
        'kind' => 'expense',
        'amount_cents' => -10000,
        'date' => '2026-10-20',
        'payee' => 'Carrefour',
        'splits' => [
            ['category_id' => F::category($this->user, 'Supermercado')->id, 'amount_cents' => -7000],
            ['category_id' => F::category($this->user, 'Ropa')->id, 'amount_cents' => -3000],
        ],
    ])->assertCreated()
        ->assertJsonPath('data.category', null)
        ->assertJsonCount(2, 'data.splits');

    $this->postJson('/api/v1/finance/transactions', [
        'account_id' => $this->account->id,
        'kind' => 'expense',
        'amount_cents' => -10000,
        'date' => '2026-10-20',
        'splits' => [
            ['category_id' => F::category($this->user, 'Supermercado')->id, 'amount_cents' => -7000],
        ],
    ])->assertUnprocessable()->assertJsonValidationErrors('splits');

    $this->getJson('/api/v1/finance/transactions?category_id[]='.F::category($this->user, 'Ropa')->id)
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.id', $response->json('data.id'));
});

it('filters, paginates with a cursor and returns totals of the filtered set', function () {
    $other = F::account($this->user, ['name' => 'Tarjeta', 'type' => 'credit_card']);
    F::expense($this->user, $this->account, 4250, '2026-10-01', 'Supermercado', ['payee' => 'Mercadona', 'tags' => ['casa']]);
    F::expense($this->user, $this->account, 1500, '2026-10-02', 'Restaurantes', ['payee' => 'Bar Pepe']);
    F::expense($this->user, $other, 9000, '2026-10-03', 'Ropa', ['payee' => 'Zara', 'status' => 'pending']);
    F::expense($this->user, $this->account, 2000, '2026-10-04', null, ['payee' => 'Desconocido']);
    F::income($this->user, $this->account, 250000, '2026-10-05', 'Nómina', ['payee' => 'ACME']);
    F::transfer($this->user, $this->account, $other, 5000, '2026-10-06');

    $this->getJson('/api/v1/finance/transactions')
        ->assertOk()
        ->assertJsonCount(7, 'data')
        ->assertJsonPath('meta.totals.count', 7)
        ->assertJsonPath('meta.totals.income_cents', 250000)
        ->assertJsonPath('meta.totals.expense_cents', -16750)
        ->assertJsonPath('meta.totals.net_cents', 250000 - 16750);

    $this->getJson('/api/v1/finance/transactions?category_id[]='.F::category($this->user, 'Alimentación')->id)
        ->assertJsonCount(2, 'data')
        ->assertJsonPath('meta.totals.expense_cents', -5750);

    $this->getJson('/api/v1/finance/transactions?category_id=none')->assertJsonCount(1, 'data')->assertJsonPath('data.0.payee', 'Desconocido');
    $this->getJson('/api/v1/finance/transactions?account_id[]='.$other->id)->assertJsonCount(2, 'data');
    $this->getJson('/api/v1/finance/transactions?tag[]=casa')->assertJsonCount(1, 'data');
    $this->getJson('/api/v1/finance/transactions?kind[]=income')->assertJsonCount(1, 'data');
    $this->getJson('/api/v1/finance/transactions?kind=expense,income')->assertJsonCount(5, 'data');
    $this->getJson('/api/v1/finance/transactions?min=2000&max=9000')->assertJsonCount(5, 'data');
    $this->getJson('/api/v1/finance/transactions?q=merca')->assertJsonCount(1, 'data');
    $this->getJson('/api/v1/finance/transactions?status=pending')->assertJsonCount(1, 'data');
    $this->getJson('/api/v1/finance/transactions?from=2026-10-02&to=2026-10-04')->assertJsonCount(3, 'data');

    $first = $this->getJson('/api/v1/finance/transactions?per_page=4')
        ->assertJsonCount(4, 'data')
        ->assertJsonPath('meta.has_more', true)
        ->assertJsonPath('meta.totals.count', 7);
    $cursor = $first->json('meta.next_cursor');

    $second = $this->getJson('/api/v1/finance/transactions?per_page=4&cursor='.$cursor)
        ->assertJsonCount(3, 'data')
        ->assertJsonPath('meta.has_more', false)
        ->assertJsonPath('meta.next_cursor', null);

    $ids = array_merge(array_column($first->json('data'), 'id'), array_column($second->json('data'), 'id'));
    expect(array_unique($ids))->toHaveCount(7)
        ->and($first->json('data.0.date'))->toBe('2026-10-06');
});

it('filters by period', function () {
    F::income($this->user, $this->account, 250000, '2026-09-28');
    F::expense($this->user, $this->account, 1000, '2026-10-10');
    F::income($this->user, $this->account, 250000, '2026-10-24');
    F::expense($this->user, $this->account, 2000, '2026-10-24');

    $periods = $this->getJson('/api/v1/finance/periods')->json('data');

    $this->getJson('/api/v1/finance/transactions?period_id='.$periods[1]['id'])->assertJsonCount(2, 'data');
    $this->getJson('/api/v1/finance/transactions?period_id='.$periods[0]['id'])->assertJsonCount(2, 'data');
});

it('bulk edits category, account and tags', function () {
    $a = F::expense($this->user, $this->account, 1000, '2026-10-20', null, ['tags' => ['viejo']]);
    $b = F::expense($this->user, $this->account, 2000, '2026-10-21', null);
    $card = F::account($this->user, ['name' => 'Tarjeta']);

    $this->patchJson('/api/v1/finance/transactions/bulk', [
        'ids' => [$a->id, $b->id],
        'category_id' => F::category($this->user, 'Ocio')->id,
        'account_id' => $card->id,
        'add_tags' => ['vacaciones-2026'],
        'remove_tags' => ['viejo'],
    ])->assertOk()->assertJsonPath('data.updated', 2);

    expect(Transaction::query()->whereIn('id', [$a->id, $b->id])->pluck('account_id')->unique()->all())->toBe([$card->id])
        ->and($a->refresh()->tags->pluck('name')->all())->toBe(['vacaciones-2026'])
        ->and($b->refresh()->category?->name)->toBe('Ocio');
});

it('suggests payees with their usual category', function () {
    F::expense($this->user, $this->account, 1000, '2026-10-01', 'Supermercado', ['payee' => 'Mercadona']);
    F::expense($this->user, $this->account, 1200, '2026-10-08', 'Supermercado', ['payee' => 'Mercadona']);
    F::expense($this->user, $this->account, 1300, '2026-10-10', 'Restaurantes', ['payee' => 'Mercadona']);
    F::expense($this->user, $this->account, 900, '2026-10-12', 'Cafeterías', ['payee' => 'Merendero']);

    $this->getJson('/api/v1/finance/payees/suggest?q=merc')
        ->assertOk()
        ->assertJsonPath('data.0.payee', 'Mercadona')
        ->assertJsonPath('data.0.count', 3)
        ->assertJsonPath('data.0.category.name', 'Supermercado')
        ->assertJsonPath('data.0.last_amount_cents', -1300);
});

it('suggests a category from the payee or, failing that, the concept', function () {
    F::expense($this->user, $this->account, 1200, '2026-10-05', 'Supermercado', ['payee' => 'Mercadona']);
    F::expense($this->user, $this->account, 3000, '2026-10-06', 'Restaurantes', ['description' => 'Cena con amigos']);
    F::expense($this->user, $this->account, 2800, '2026-10-12', 'Restaurantes', ['description' => 'cena con amigos ']);

    $this->getJson('/api/v1/finance/categories/suggest?description='.urlencode('Cena con amigos'))
        ->assertOk()
        ->assertJsonPath('data.source', 'description')
        ->assertJsonPath('data.category.name', 'Restaurantes');

    $this->getJson('/api/v1/finance/categories/suggest?payee=mercadona&description='.urlencode('Cena con amigos'))
        ->assertJsonPath('data.source', 'payee')
        ->assertJsonPath('data.category.name', 'Supermercado');

    $this->getJson('/api/v1/finance/categories/suggest?payee=Desconocido&kind=expense')
        ->assertOk()
        ->assertJsonPath('data.category', null);

    $this->getJson('/api/v1/finance/categories/suggest')->assertUnprocessable();
});

it('stores finance timestamps as the real instant', function () {
    $transaction = F::expense($this->user, $this->account, 1000, '2026-10-20');

    $epoch = (int) DB::selectOne('SELECT extract(epoch FROM created_at)::bigint AS epoch FROM finance.transactions WHERE id = ?', [$transaction->id])->epoch;

    expect($epoch)->toBe(now()->getTimestamp())
        ->and($transaction->refresh()->created_at?->getTimestamp())->toBe(now()->getTimestamp());

    $this->getJson("/api/v1/finance/transactions/{$transaction->id}")
        ->assertJsonPath('data.created_at', now()->toIso8601String());
});

it('manages tags: rename, merge and delete', function () {
    $transaction = F::expense($this->user, $this->account, 1000, '2026-10-20', null, ['tags' => ['viaje', 'verano']]);
    $viaje = Tag::query()->where('name', 'viaje')->firstOrFail();
    $verano = Tag::query()->where('name', 'verano')->firstOrFail();

    $this->getJson('/api/v1/finance/tags')->assertJsonCount(2, 'data')->assertJsonPath('data.0.transactions_count', 1);
    $this->patchJson("/api/v1/finance/tags/{$viaje->id}", ['name' => 'verano'])->assertUnprocessable();
    $this->patchJson("/api/v1/finance/tags/{$viaje->id}", ['name' => 'Vacaciones 2026'])->assertOk()->assertJsonPath('data.name', 'vacaciones 2026');
    $this->postJson("/api/v1/finance/tags/{$verano->id}/merge", ['into_tag_id' => $viaje->id])->assertOk();

    expect($transaction->refresh()->tags->pluck('name')->all())->toBe(['vacaciones 2026']);

    $this->deleteJson("/api/v1/finance/tags/{$viaje->id}")->assertNoContent();
    expect($transaction->refresh()->tags)->toHaveCount(0);
});
