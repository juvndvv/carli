<?php

use App\Models\User;
use App\Modules\Notes\Domain\Services\DefaultSections;
use App\Modules\Notes\Models\Note;
use App\Modules\Notes\Models\ShoppingSection;
use App\Modules\Notes\tests\Support\NotesFixtures as N;
use Carbon\CarbonImmutable;

beforeEach(function () {
    $this->travelTo(CarbonImmutable::parse('2026-10-26 12:00:00', 'Europe/Madrid'));
});

it('seeds the default shopping sections once on first access', function () {
    $user = User::factory()->create();
    $this->actingAs($user);

    $this->getJson('/api/v1/notes/snapshot')
        ->assertOk()
        ->assertJsonPath('data.sections.*.name', DefaultSections::NAMES)
        ->assertJsonPath('data.sections.*.position', range(0, 9));

    app()->forgetScopedInstances();
    $this->getJson('/api/v1/notes/snapshot')->assertOk()->assertJsonCount(10, 'data.sections');
    app(DefaultSections::class)->seedFor($user);

    expect(ShoppingSection::query()->ownedBy($user)->count())->toBe(10);
});

it('does not reseed sections for a user who already uses the module', function () {
    $user = N::user();
    $this->actingAs($user);
    N::sync($this, [N::op('note.upsert', ['id' => N::id(), 'type' => 'text', 'body' => 'Hola'])]);
    ShoppingSection::query()->ownedBy($user)->delete();

    app()->forgetScopedInstances();
    $this->getJson('/api/v1/notes/snapshot')->assertOk()->assertJsonCount(0, 'data.sections');
});

it('returns the snapshot shape', function () {
    $user = N::user();
    $this->actingAs($user);
    $folderId = N::id();
    $noteId = N::id();
    $productId = N::id();
    $itemId = N::id();

    N::sync($this, [
        N::op('folder.upsert', ['id' => $folderId, 'name' => 'Casa', 'position' => 1]),
        N::op('note.upsert', ['id' => $noteId, 'type' => 'shopping', 'title' => 'Compra', 'folder_id' => $folderId]),
        N::op('product.upsert', ['id' => $productId, 'note_id' => $noteId, 'name' => 'Leche', 'default_quantity' => '2 L']),
        N::op('item.upsert', ['id' => $itemId, 'note_id' => $noteId, 'text' => 'Leche', 'product_id' => $productId, 'position' => 3]),
    ]);

    $response = $this->getJson('/api/v1/notes/snapshot')->assertOk();

    $response->assertJsonStructure(['data' => [
        'server_time',
        'folders' => [['id', 'parent_id', 'name', 'position', 'created_at', 'updated_at']],
        'notes' => [['id', 'folder_id', 'type', 'title', 'body', 'pinned_at', 'archived_at', 'deleted_at', 'checked_behavior', 'is_primary', 'sort', 'created_at', 'updated_at',
            'items' => [['id', 'note_id', 'product_id', 'text', 'quantity', 'section_id', 'checked_at', 'position', 'updated_at']]]],
        'sections' => [['id', 'name', 'position', 'updated_at']],
        'products' => [['id', 'note_id', 'name', 'section_id', 'default_quantity', 'restock_mode', 'restock_interval_days', 'last_bought_at', 'times_bought', 'restocked_for', 'updated_at']],
    ]]);

    expect(array_keys($response->json('data.notes.0')))->toHaveCount(14)
        ->and(array_keys($response->json('data.notes.0.items.0')))->toHaveCount(9)
        ->and(array_keys($response->json('data.products.0')))->toHaveCount(11);

    $response->assertJsonPath('data.server_time', '2026-10-26T11:00:00.000000Z')
        ->assertJsonPath('data.notes.0.checked_behavior', 'move')
        ->assertJsonPath('data.notes.0.is_primary', true)
        ->assertJsonPath('data.notes.0.folder_id', $folderId)
        ->assertJsonPath('data.notes.0.items.0.id', $itemId)
        ->assertJsonPath('data.notes.0.items.0.position', 3)
        ->assertJsonPath('data.products.0.restock_mode', 'none')
        ->assertJsonPath('data.products.0.times_bought', 0);
});

it('includes archived and trashed notes and purges trash older than 30 days', function () {
    $user = N::user();
    $this->actingAs($user);
    $archived = N::id();
    $trashed = N::id();
    $old = N::id();

    N::sync($this, [
        N::op('note.upsert', ['id' => $old, 'type' => 'text', 'body' => 'Viejo', 'deleted' => true], '2026-09-20T10:00:00.000Z'),
        N::op('note.upsert', ['id' => $archived, 'type' => 'text', 'body' => 'Archivada', 'archived' => true]),
        N::op('note.upsert', ['id' => $trashed, 'type' => 'list', 'title' => 'Papelera', 'deleted' => true]),
    ]);

    $ids = collect($this->getJson('/api/v1/notes/snapshot')->assertOk()->json('data.notes'))->pluck('id');

    expect($ids->all())->toEqualCanonicalizing([$archived, $trashed])
        ->and(Note::query()->whereKey($old)->exists())->toBeFalse();
});

it('is forbidden when the module is disabled', function () {
    $user = N::user();
    $this->actingAs($user);

    $this->patchJson('/api/v1/modules/notes', ['enabled' => false])->assertOk();

    $this->getJson('/api/v1/notes/snapshot')->assertForbidden();
    $this->postJson('/api/v1/notes/sync', ['operations' => []])->assertForbidden();
    $this->getJson('/api/v1/notes/search?q=hola')->assertForbidden();
});

it('exposes the module manifest', function () {
    $this->actingAs(N::user());

    $modules = collect($this->getJson('/api/v1/modules')->assertOk()->json('data'))->keyBy('id');

    expect($modules['notes'])->toMatchArray([
        'name' => 'Notas',
        'icon' => 'notebook-pen',
        'route' => '/notas',
        'description' => 'Notas, listas y la lista de la compra.',
        'available' => true,
        'enabled' => true,
        'settings' => ['checked_behavior' => 'move'],
    ]);
});

it('adds nothing to the pending summary', function () {
    $user = N::user();
    $this->actingAs($user);
    $noteId = N::id();

    N::sync($this, [
        N::op('note.upsert', ['id' => $noteId, 'type' => 'list', 'title' => 'Maleta']),
        N::op('item.upsert', ['id' => N::id(), 'note_id' => $noteId, 'text' => 'Cargador']),
    ]);

    $this->getJson('/api/v1/pending/summary')->assertOk()->assertJsonPath('data.total', 0);
    $this->getJson('/api/v1/pending?module=notes')->assertOk()->assertJsonCount(0, 'data');
});
