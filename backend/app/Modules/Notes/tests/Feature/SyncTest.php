<?php

use App\Models\User;
use App\Modules\Notes\Models\Folder;
use App\Modules\Notes\Models\Note;
use App\Modules\Notes\Models\NoteItem;
use App\Modules\Notes\Models\ShoppingProduct;
use App\Modules\Notes\Models\ShoppingSection;
use App\Modules\Notes\Models\SyncOperation;
use App\Modules\Notes\tests\Support\NotesFixtures as N;
use Carbon\CarbonImmutable;

beforeEach(function () {
    $this->travelTo(CarbonImmutable::parse('2026-10-26 12:00:00', 'Europe/Madrid'));
    $this->user = N::user();
    $this->actingAs($this->user);
});

function noteRow(string $id): Note
{
    return Note::query()->withoutGlobalScope('user')->findOrFail($id);
}

it('validates the envelope with 422', function () {
    $this->postJson('/api/v1/notes/sync', [])->assertUnprocessable()->assertJsonValidationErrors('operations');
    $this->postJson('/api/v1/notes/sync', ['operations' => [['id' => 'nope', 'type' => 'note.upsert', 'at' => 'ayer', 'payload' => []]]])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['operations.0.id', 'operations.0.at']);
    $this->postJson('/api/v1/notes/sync', ['operations' => array_fill(0, 501, N::op('note.upsert', []))])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('operations');
});

it('returns results and the snapshot', function () {
    $op = N::op('note.upsert', ['id' => N::id(), 'type' => 'text', 'body' => 'Hola']);

    N::sync($this, [$op])
        ->assertJsonPath('results', [['id' => $op['id'], 'status' => 'applied', 'error' => null]])
        ->assertJsonPath('data.notes.0.body', 'Hola')
        ->assertJsonCount(10, 'data.sections');
});

it('treats a repeated operation id as a duplicate', function () {
    $noteId = N::id();
    $create = N::op('note.upsert', ['id' => $noteId, 'type' => 'text', 'body' => 'Primera']);

    expect(N::statuses($this, [$create, $create]))->toBe(['applied', 'duplicate']);

    $edit = N::op('note.upsert', ['id' => $noteId, 'body' => 'Segunda']);
    N::sync($this, [$edit]);
    N::sync($this, [N::op('note.upsert', ['id' => $noteId, 'body' => 'Tercera'], id: $create['id'])])
        ->assertJsonPath('results.0.status', 'duplicate');

    expect(noteRow($noteId)->body)->toBe('Segunda')
        ->and(SyncOperation::query()->count())->toBe(2);
});

it('rejects stale writes with last writer wins', function () {
    $noteId = N::id();

    expect(N::statuses($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'text', 'body' => 'Nueva'], '2026-10-26T10:00:00.500Z'),
        N::op('note.upsert', ['id' => $noteId, 'body' => 'Vieja'], '2026-10-26T10:00:00.200Z'),
        N::op('note.upsert', ['id' => $noteId, 'body' => 'Misma hora'], '2026-10-26T10:00:00.500Z'),
    ]))->toBe(['applied', 'stale', 'applied']);

    $note = noteRow($noteId);

    expect($note->body)->toBe('Misma hora')
        ->and($note->updated_at?->toJSON())->toBe('2026-10-26T10:00:00.500000Z')
        ->and($note->created_at?->toJSON())->toBe('2026-10-26T10:00:00.500000Z');
});

it('writes only the keys present in the payload', function () {
    $noteId = N::id();

    N::sync($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'text', 'title' => 'Caldera', 'body' => 'Modelo X', 'sort' => 4, 'checked_behavior' => 'inline']),
        N::op('note.upsert', ['id' => $noteId, 'body' => 'Modelo Y']),
        N::op('note.upsert', ['id' => $noteId, 'title' => null]),
    ]);

    $note = noteRow($noteId);

    expect($note->title)->toBeNull()
        ->and($note->body)->toBe('Modelo Y')
        ->and($note->sort)->toBe(4)
        ->and($note->checked_behavior->value)->toBe('inline');
});

it('rejects creations without their required keys', function () {
    $noteId = N::id();
    N::sync($this, [N::op('note.upsert', ['id' => $noteId, 'type' => 'list'])]);

    $response = N::sync($this, [
        N::op('note.upsert', ['id' => N::id(), 'title' => 'Sin tipo']),
        N::op('folder.upsert', ['id' => N::id()]),
        N::op('item.upsert', ['id' => N::id(), 'note_id' => $noteId]),
        N::op('item.upsert', ['id' => N::id(), 'text' => 'Sin nota']),
        N::op('note.upsert', ['id' => N::id(), 'type' => 'poema']),
        N::op('mystery.upsert', ['id' => N::id()]),
    ]);

    expect($response->json('results.*.status'))->toBe(array_fill(0, 6, 'rejected'))
        ->and($response->json('results.0.error'))->toBe('La nota necesita un tipo.')
        ->and($response->json('results.5.error'))->toBe('Tipo de operación desconocido.')
        ->and(Note::query()->count())->toBe(1);
});

it('rejects operations on rows of another user', function () {
    $other = User::factory()->create();
    $foreign = new Note(['type' => 'text', 'body' => 'Ajena']);
    $foreign->id = N::id();
    $foreign->user_id = $other->id;
    $foreign->save();
    $foreignItem = new NoteItem(['text' => 'Ajeno']);
    $foreignItem->id = N::id();
    $foreignItem->note_id = $foreign->id;
    $foreignItem->save();

    $response = N::sync($this, [
        N::op('note.upsert', ['id' => $foreign->id, 'body' => 'Mía']),
        N::op('note.purge', ['id' => $foreign->id]),
        N::op('item.upsert', ['id' => N::id(), 'note_id' => $foreign->id, 'text' => 'Intruso']),
        N::op('item.upsert', ['id' => $foreignItem->id, 'checked' => true]),
        N::op('item.delete', ['id' => $foreignItem->id]),
    ]);

    expect($response->json('results.*.status'))->toBe(array_fill(0, 5, 'rejected'))
        ->and(noteRow($foreign->id)->body)->toBe('Ajena')
        ->and(NoteItem::query()->whereKey($foreignItem->id)->first()?->checked_at)->toBeNull()
        ->and(NoteItem::query()->where('text', 'Intruso')->exists())->toBeFalse()
        ->and($response->json('data.notes'))->toBe([]);
});

it('rejects folder cycles', function () {
    [$casa, $reformas, $cocina] = [N::id(), N::id(), N::id()];

    N::sync($this, [
        N::op('folder.upsert', ['id' => $casa, 'name' => 'Casa']),
        N::op('folder.upsert', ['id' => $reformas, 'name' => 'Reformas', 'parent_id' => $casa]),
        N::op('folder.upsert', ['id' => $cocina, 'name' => 'Cocina', 'parent_id' => $reformas]),
    ]);

    $response = N::sync($this, [
        N::op('folder.upsert', ['id' => $casa, 'parent_id' => $cocina]),
        N::op('folder.upsert', ['id' => $casa, 'parent_id' => $casa]),
        N::op('folder.upsert', ['id' => $casa, 'parent_id' => N::id()]),
        N::op('folder.upsert', ['id' => $cocina, 'parent_id' => $casa]),
    ]);

    expect($response->json('results.*.status'))->toBe(['rejected', 'rejected', 'rejected', 'applied'])
        ->and($response->json('results.0.error'))->toBe('Una carpeta no puede estar dentro de sí misma.')
        ->and(Folder::query()->findOrFail($casa)->parent_id)->toBeNull()
        ->and(Folder::query()->findOrFail($cocina)->parent_id)->toBe($casa);
});

it('moves the content of a deleted folder to its parent', function () {
    [$casa, $reformas, $cocina, $nota, $raiz] = [N::id(), N::id(), N::id(), N::id(), N::id()];

    N::sync($this, [
        N::op('folder.upsert', ['id' => $casa, 'name' => 'Casa']),
        N::op('folder.upsert', ['id' => $reformas, 'name' => 'Reformas', 'parent_id' => $casa]),
        N::op('folder.upsert', ['id' => $cocina, 'name' => 'Cocina', 'parent_id' => $reformas]),
        N::op('note.upsert', ['id' => $nota, 'type' => 'text', 'body' => 'Presupuesto', 'folder_id' => $reformas]),
        N::op('note.upsert', ['id' => $raiz, 'type' => 'text', 'body' => 'Raíz', 'folder_id' => $casa]),
    ]);

    expect(N::statuses($this, [
        N::op('folder.delete', ['id' => $reformas]),
        N::op('folder.delete', ['id' => $reformas]),
        N::op('folder.delete', ['id' => $casa]),
    ]))->toBe(['applied', 'applied', 'applied']);

    expect(Folder::query()->pluck('id')->all())->toBe([$cocina])
        ->and(Folder::query()->findOrFail($cocina)->parent_id)->toBeNull()
        ->and(noteRow($nota)->folder_id)->toBeNull()
        ->and(noteRow($raiz)->folder_id)->toBeNull();
});

it('pins, archives, trashes, restores and purges notes', function () {
    $noteId = N::id();

    N::sync($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'text', 'body' => 'Wifi', 'pinned' => true], '2026-10-26T09:00:00.000Z'),
        N::op('note.upsert', ['id' => $noteId, 'pinned' => true, 'archived' => true], '2026-10-26T09:05:00.000Z'),
    ]);

    $note = noteRow($noteId);
    expect($note->pinned_at?->toJSON())->toBe('2026-10-26T09:00:00.000000Z')
        ->and($note->archived_at?->toJSON())->toBe('2026-10-26T09:05:00.000000Z');

    N::sync($this, [N::op('note.upsert', ['id' => $noteId, 'pinned' => false, 'archived' => false, 'deleted' => true], '2026-10-26T09:10:00.000Z')]);
    $note = noteRow($noteId);
    expect($note->pinned_at)->toBeNull()
        ->and($note->archived_at)->toBeNull()
        ->and($note->deleted_at?->toJSON())->toBe('2026-10-26T09:10:00.000000Z');

    N::sync($this, [N::op('note.upsert', ['id' => $noteId, 'deleted' => false], '2026-10-26T09:15:00.000Z')]);
    expect(noteRow($noteId)->deleted_at)->toBeNull();

    expect(N::statuses($this, [N::op('note.purge', ['id' => $noteId]), N::op('note.purge', ['id' => $noteId])]))->toBe(['applied', 'applied'])
        ->and(Note::query()->whereKey($noteId)->exists())->toBeFalse();
});

it('allows switching between text and list but not to or from shopping', function () {
    [$text, $shopping] = [N::id(), N::id()];

    N::sync($this, [
        N::op('note.upsert', ['id' => $text, 'type' => 'text', 'body' => 'Uno']),
        N::op('note.upsert', ['id' => $shopping, 'type' => 'shopping']),
    ]);

    expect(N::statuses($this, [
        N::op('note.upsert', ['id' => $text, 'type' => 'list']),
        N::op('note.upsert', ['id' => $text, 'type' => 'shopping']),
        N::op('note.upsert', ['id' => $shopping, 'type' => 'list']),
    ]))->toBe(['applied', 'rejected', 'rejected'])
        ->and(noteRow($text)->type->value)->toBe('list');
});

it('keeps a single primary shopping note per user', function () {
    [$first, $second, $third, $list] = [N::id(), N::id(), N::id(), N::id()];

    N::sync($this, [
        N::op('note.upsert', ['id' => $first, 'type' => 'shopping', 'title' => 'Súper']),
        N::op('note.upsert', ['id' => $second, 'type' => 'shopping', 'title' => 'Ferretería']),
    ]);

    expect(noteRow($first)->is_primary)->toBeTrue()
        ->and(noteRow($second)->is_primary)->toBeFalse();

    $response = N::sync($this, [
        N::op('note.upsert', ['id' => $second, 'is_primary' => true]),
        N::op('note.upsert', ['id' => $third, 'type' => 'shopping', 'is_primary' => true]),
        N::op('note.upsert', ['id' => $list, 'type' => 'list', 'is_primary' => true]),
    ]);

    expect($response->json('results.*.status'))->toBe(['applied', 'applied', 'rejected'])
        ->and(Note::query()->where('is_primary', true)->pluck('id')->all())->toBe([$third]);
});

it('checks and unchecks items', function () {
    [$noteId, $itemId] = [N::id(), N::id()];

    N::sync($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'list', 'title' => 'Maleta']),
        N::op('item.upsert', ['id' => $itemId, 'note_id' => $noteId, 'text' => 'Pasaporte', 'position' => 2]),
        N::op('item.upsert', ['id' => $itemId, 'checked' => true], '2026-10-26T11:30:00.000Z'),
    ])->assertJsonPath('data.notes.0.items.0.checked_at', '2026-10-26T11:30:00.000000Z');

    N::sync($this, [N::op('item.upsert', ['id' => $itemId, 'checked' => false, 'text' => 'Pasaporte y DNI'], '2026-10-26T11:31:00.000Z')]);

    $item = NoteItem::query()->findOrFail($itemId);
    expect($item->checked_at)->toBeNull()
        ->and($item->text)->toBe('Pasaporte y DNI')
        ->and($item->position)->toBe(2);

    expect(N::statuses($this, [N::op('item.delete', ['id' => $itemId]), N::op('item.delete', ['id' => $itemId])]))->toBe(['applied', 'applied'])
        ->and(NoteItem::query()->count())->toBe(0);
});

it('upserts shopping products', function () {
    [$noteId, $listId, $productId] = [N::id(), N::id(), N::id()];
    $section = ShoppingSection::query()->orderBy('position')->firstOrFail();

    N::sync($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'shopping']),
        N::op('note.upsert', ['id' => $listId, 'type' => 'list']),
    ]);

    $response = N::sync($this, [
        N::op('product.upsert', ['id' => N::id(), 'note_id' => $listId, 'name' => 'Leche']),
        N::op('product.upsert', ['id' => $productId, 'note_id' => $noteId, 'name' => '  Plátanos   de  Canarias ', 'section_id' => $section->id]),
        N::op('product.upsert', ['id' => $productId, 'restock_mode' => 'interval']),
        N::op('product.upsert', ['id' => $productId, 'restock_mode' => 'interval', 'restock_interval_days' => 0]),
        N::op('product.upsert', ['id' => $productId, 'restock_mode' => 'interval', 'restock_interval_days' => 7, 'default_quantity' => '1 kg']),
    ]);

    expect($response->json('results.*.status'))->toBe(['rejected', 'applied', 'rejected', 'rejected', 'applied']);

    $product = ShoppingProduct::query()->findOrFail($productId);
    expect($product->name)->toBe('Plátanos   de  Canarias')
        ->and($product->name_normalized)->toBe('platanos de canarias')
        ->and($product->section_id)->toBe($section->id)
        ->and($product->restock_mode->value)->toBe('interval')
        ->and($product->restock_interval_days)->toBe(7)
        ->and($product->default_quantity)->toBe('1 kg');

    N::sync($this, [N::op('section.delete', ['id' => $section->id])]);
    expect(ShoppingProduct::query()->findOrFail($productId)->section_id)->toBeNull();

    N::sync($this, [N::op('product.delete', ['id' => $productId])]);
    expect(ShoppingProduct::query()->count())->toBe(0);
});

it('lets the client restore purchase stats on a product', function () {
    [$noteId, $productId] = [N::id(), N::id()];

    N::sync($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'shopping']),
        N::op('product.upsert', ['id' => $productId, 'note_id' => $noteId, 'name' => 'Aceite', 'restock_mode' => 'interval', 'restock_interval_days' => 30]),
    ]);

    expect(N::statuses($this, [
        N::op('product.upsert', ['id' => $productId, 'last_bought_at' => '2026-10-20T08:15:42.789Z', 'times_bought' => 3, 'restocked_for' => "{$productId}:1"], '2026-10-26T11:10:00.000Z'),
        N::op('product.upsert', ['id' => $productId, 'times_bought' => -1], '2026-10-26T11:11:00.000Z'),
        N::op('product.upsert', ['id' => $productId, 'times_bought' => 9], '2026-10-26T11:05:00.000Z'),
    ]))->toBe(['applied', 'rejected', 'stale']);

    $product = ShoppingProduct::query()->findOrFail($productId);
    expect($product->last_bought_at?->toJSON())->toBe('2026-10-20T08:15:42.000000Z')
        ->and($product->times_bought)->toBe(3)
        ->and($product->restocked_for)->toBe("{$productId}:1");

    N::sync($this, [N::op('product.upsert', ['id' => $productId, 'last_bought_at' => null, 'restocked_for' => null], '2026-10-26T11:12:00.000Z')]);

    $product->refresh();
    expect($product->last_bought_at)->toBeNull()
        ->and($product->restocked_for)->toBeNull()
        ->and($product->times_bought)->toBe(3);
});

it('creates, renames and deletes sections', function () {
    $sectionId = N::id();

    N::sync($this, [
        N::op('section.upsert', ['id' => $sectionId, 'name' => 'Mascotas', 'position' => 10]),
        N::op('section.upsert', ['id' => $sectionId, 'name' => 'Animales']),
    ])->assertJsonPath('data.sections.10.name', 'Animales');

    N::sync($this, [N::op('section.delete', ['id' => $sectionId])])->assertJsonCount(10, 'data.sections');
});

it('purges processed operations older than 30 days', function () {
    $old = N::op('note.upsert', ['id' => N::id(), 'type' => 'text', 'body' => 'Uno']);
    N::sync($this, [$old]);

    $this->travel(31)->days();
    N::sync($this, [N::op('note.upsert', ['id' => N::id(), 'type' => 'text', 'body' => 'Dos'])]);

    expect(SyncOperation::query()->whereKey($old['id'])->exists())->toBeFalse()
        ->and(SyncOperation::query()->count())->toBe(1);
});

it('keeps blank item texts and untrimmed bodies', function () {
    [$noteId, $itemId] = [N::id(), N::id()];

    expect(N::statuses($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'list', 'title' => '', 'body' => 'Hola ']),
        N::op('item.upsert', ['id' => $itemId, 'note_id' => $noteId, 'text' => '']),
        N::op('item.upsert', ['id' => N::id(), 'note_id' => $noteId, 'text' => null]),
    ]))->toBe(['applied', 'applied', 'rejected']);

    expect(NoteItem::query()->findOrFail($itemId)->text)->toBe('')
        ->and(noteRow($noteId)->body)->toBe('Hola ')
        ->and(noteRow($noteId)->title)->toBe('');

    N::sync($this, [N::op('item.upsert', ['id' => $itemId, 'text' => 'Toalla'], '2026-10-26T11:30:00.000Z')]);

    expect(NoteItem::query()->findOrFail($itemId)->text)->toBe('Toalla');
});
