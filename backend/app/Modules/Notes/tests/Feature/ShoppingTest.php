<?php

use App\Modules\Notes\Domain\Services\RestockService;
use App\Modules\Notes\Models\NoteItem;
use App\Modules\Notes\Models\ShoppingProduct;
use App\Modules\Notes\tests\Support\NotesFixtures as N;
use Carbon\CarbonImmutable;

beforeEach(function () {
    $this->travelTo(CarbonImmutable::parse('2026-10-24 11:00:00', 'Europe/Madrid'));
    $this->user = N::user();
    $this->actingAs($this->user);
    $this->noteId = N::id();
    N::sync($this, [N::op('note.upsert', ['id' => $this->noteId, 'type' => 'shopping', 'title' => 'Súper'])]);
});

/**
 * @param  array<string, mixed>  $attributes
 * @return array{product: string, item: string}
 */
function productInCart(object $test, string $name, array $attributes = []): array
{
    $productId = N::id();
    $itemId = N::id();

    N::sync($test, [
        N::op('product.upsert', ['id' => $productId, 'note_id' => $test->noteId, 'name' => $name, ...$attributes]),
        N::op('item.upsert', ['id' => $itemId, 'note_id' => $test->noteId, 'product_id' => $productId, 'text' => $name, 'checked' => true]),
    ]);

    return ['product' => $productId, 'item' => $itemId];
}

function finishTrip(object $test, array $itemIds, string $finishedAt = '2026-10-24T09:30:15.750Z'): void
{
    N::sync($test, [N::op('shopping.finish', ['note_id' => $test->noteId, 'item_ids' => $itemIds, 'finished_at' => $finishedAt])])
        ->assertJsonPath('results.0.status', 'applied');
}

function restockItemId(string $productId): string
{
    $product = ShoppingProduct::query()->findOrFail($productId);

    return RestockService::itemId(RestockService::cycleKey($product->id, $product->last_bought_at ?? throw new LogicException));
}

it('finishes a trip removing the bought items and stamping the products', function () {
    $milk = productInCart($this, 'Leche');
    $loose = N::id();
    $pending = N::id();
    N::sync($this, [
        N::op('item.upsert', ['id' => $loose, 'note_id' => $this->noteId, 'text' => 'Pilas', 'checked' => true]),
        N::op('item.upsert', ['id' => $pending, 'note_id' => $this->noteId, 'text' => 'Pan']),
    ]);

    finishTrip($this, [$milk['item'], $loose, N::id()]);

    $product = ShoppingProduct::query()->findOrFail($milk['product']);

    expect(NoteItem::query()->pluck('id')->all())->toBe([$pending])
        ->and($product->last_bought_at?->toJSON())->toBe('2026-10-24T09:30:15.000000Z')
        ->and($product->times_bought)->toBe(1)
        ->and($product->restocked_for)->toBeNull();
});

it('is idempotent by operation id', function () {
    $milk = productInCart($this, 'Leche');
    $finish = N::op('shopping.finish', ['note_id' => $this->noteId, 'item_ids' => [$milk['item']], 'finished_at' => '2026-10-24T09:30:00Z']);

    expect(N::statuses($this, [$finish, $finish]))->toBe(['applied', 'duplicate'])
        ->and(ShoppingProduct::query()->findOrFail($milk['product'])->times_bought)->toBe(1);
});

it('rejects finishing a note that is not a shopping list', function () {
    $listId = N::id();
    N::sync($this, [N::op('note.upsert', ['id' => $listId, 'type' => 'list'])]);

    expect(N::statuses($this, [
        N::op('shopping.finish', ['note_id' => $listId, 'item_ids' => [], 'finished_at' => '2026-10-24T09:30:00Z']),
        N::op('shopping.finish', ['note_id' => N::id(), 'item_ids' => [], 'finished_at' => '2026-10-24T09:30:00Z']),
        N::op('shopping.finish', ['note_id' => $this->noteId, 'finished_at' => '2026-10-24T09:30:00Z']),
    ]))->toBe(['rejected', 'rejected', 'rejected']);
});

it('brings every trip products back with the deterministic id', function () {
    $milk = productInCart($this, 'Leche', ['restock_mode' => 'every_trip', 'default_quantity' => '6 bricks']);
    $section = $this->getJson('/api/v1/notes/snapshot')->json('data.sections.3.id');
    N::sync($this, [N::op('product.upsert', ['id' => $milk['product'], 'section_id' => $section])]);

    finishTrip($this, [$milk['item']]);

    $expectedId = RestockService::itemId($milk['product'].':'.CarbonImmutable::parse('2026-10-24T09:30:15Z')->getTimestamp());
    $item = NoteItem::query()->findOrFail($expectedId);

    expect($expectedId)->toBe(restockItemId($milk['product']))
        ->and($item->product_id)->toBe($milk['product'])
        ->and($item->text)->toBe('Leche')
        ->and($item->quantity)->toBe('6 bricks')
        ->and($item->section_id)->toBe($section)
        ->and($item->checked_at)->toBeNull()
        ->and(ShoppingProduct::query()->findOrFail($milk['product'])->restocked_for)->toBe($milk['product'].':'.CarbonImmutable::parse('2026-10-24T09:30:15Z')->getTimestamp());
});

it('brings interval products back only when they are due', function () {
    $paper = productInCart($this, 'Papel de cocina', ['restock_mode' => 'interval', 'restock_interval_days' => 21]);
    $pending = N::id();
    N::sync($this, [N::op('item.upsert', ['id' => $pending, 'note_id' => $this->noteId, 'text' => 'Pan', 'position' => 5])]);

    finishTrip($this, [$paper['item']]);
    expect(NoteItem::query()->where('product_id', $paper['product'])->exists())->toBeFalse();

    $this->travelTo(CarbonImmutable::parse('2026-11-13 23:59:00', 'Europe/Madrid'));
    $this->getJson('/api/v1/notes/snapshot')->assertOk();
    expect(NoteItem::query()->where('product_id', $paper['product'])->exists())->toBeFalse();

    $this->travelTo(CarbonImmutable::parse('2026-11-14 00:01:00', 'Europe/Madrid'));
    $this->getJson('/api/v1/notes/snapshot')->assertOk()
        ->assertJsonPath('data.notes.0.items.1.id', restockItemId($paper['product']))
        ->assertJsonPath('data.notes.0.items.1.position', 6)
        ->assertJsonPath('data.notes.0.items.1.text', 'Papel de cocina');
});

it('materializes once per cycle and respects a dismissal', function () {
    $milk = productInCart($this, 'Leche', ['restock_mode' => 'every_trip']);
    finishTrip($this, [$milk['item']]);
    $restocked = restockItemId($milk['product']);

    $this->getJson('/api/v1/notes/snapshot')->assertOk();
    $this->getJson('/api/v1/notes/snapshot')->assertOk();
    expect(NoteItem::query()->where('product_id', $milk['product'])->pluck('id')->all())->toBe([$restocked]);

    N::sync($this, [N::op('item.delete', ['id' => $restocked])]);
    $this->getJson('/api/v1/notes/snapshot')->assertOk();
    expect(NoteItem::query()->where('product_id', $milk['product'])->exists())->toBeFalse();

    $again = N::id();
    N::sync($this, [N::op('item.upsert', ['id' => $again, 'note_id' => $this->noteId, 'product_id' => $milk['product'], 'text' => 'Leche', 'checked' => true])]);
    finishTrip($this, [$again], '2026-10-24T09:45:00Z');

    expect(NoteItem::query()->where('product_id', $milk['product'])->pluck('id')->all())->toBe([restockItemId($milk['product'])])
        ->and(restockItemId($milk['product']))->not->toBe($restocked)
        ->and(ShoppingProduct::query()->findOrFail($milk['product'])->times_bought)->toBe(2);
});

it('does not duplicate a product that is already on the list', function () {
    $milk = productInCart($this, 'Leche', ['restock_mode' => 'every_trip']);
    $other = N::id();
    N::sync($this, [N::op('item.upsert', ['id' => $other, 'note_id' => $this->noteId, 'product_id' => $milk['product'], 'text' => 'Leche sin lactosa'])]);

    finishTrip($this, [$milk['item']]);

    expect(NoteItem::query()->where('product_id', $milk['product'])->pluck('id')->all())->toBe([$other]);
});

it('records a dismissal of an item the client materialized itself', function () {
    $milk = productInCart($this, 'Leche', ['restock_mode' => 'interval', 'restock_interval_days' => 1]);
    finishTrip($this, [$milk['item']]);
    $this->travel(2)->days();

    $clientItem = restockItemId($milk['product']);
    N::sync($this, [
        N::op('item.upsert', ['id' => $clientItem, 'note_id' => $this->noteId, 'product_id' => $milk['product'], 'text' => 'Leche']),
        N::op('item.delete', ['id' => $clientItem]),
    ])->assertJsonPath('results.*.status', ['applied', 'applied']);

    $this->getJson('/api/v1/notes/snapshot')->assertOk();

    expect(NoteItem::query()->where('product_id', $milk['product'])->exists())->toBeFalse();
});

it('skips restock on trashed shopping notes', function () {
    $milk = productInCart($this, 'Leche', ['restock_mode' => 'every_trip']);
    N::sync($this, [N::op('note.upsert', ['id' => $this->noteId, 'deleted' => true])]);

    finishTrip($this, [$milk['item']]);
    $this->getJson('/api/v1/notes/snapshot')->assertOk();

    expect(NoteItem::query()->count())->toBe(0);
});
