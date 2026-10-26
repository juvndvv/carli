<?php

use App\Models\User;
use App\Modules\Notes\Models\Note;
use App\Modules\Notes\tests\Support\NotesFixtures as N;
use Carbon\CarbonImmutable;

beforeEach(function () {
    $this->travelTo(CarbonImmutable::parse('2026-10-26 12:00:00', 'Europe/Madrid'));
    $this->user = N::user();
    $this->actingAs($this->user);

    [$this->casa, $this->reformas] = [N::id(), N::id()];
    [$this->tiles, $this->shopping, $this->pinned, $this->archived, $this->trashed] = [N::id(), N::id(), N::id(), N::id(), N::id()];

    N::sync($this, [
        N::op('folder.upsert', ['id' => $this->casa, 'name' => 'Casa']),
        N::op('folder.upsert', ['id' => $this->reformas, 'name' => 'Reformas', 'parent_id' => $this->casa]),
        N::op('note.upsert', ['id' => $this->tiles, 'type' => 'text', 'title' => 'Baño', 'folder_id' => $this->reformas,
            'body' => "Presupuesto del alicatado\nLa cerámica del suelo es gris\nLlamar al fontanero"], '2026-10-26T09:00:00Z'),
        N::op('note.upsert', ['id' => $this->shopping, 'type' => 'shopping', 'title' => 'Compra'], '2026-10-26T09:01:00Z'),
        N::op('item.upsert', ['id' => N::id(), 'note_id' => $this->shopping, 'text' => 'Jamón serrano', 'position' => 1]),
        N::op('item.upsert', ['id' => N::id(), 'note_id' => $this->shopping, 'text' => 'Pan', 'position' => 2]),
        N::op('item.upsert', ['id' => N::id(), 'note_id' => $this->shopping, 'text' => 'Jamón york', 'position' => 3]),
        N::op('note.upsert', ['id' => $this->pinned, 'type' => 'text', 'title' => 'Wifi', 'body' => 'Clave cerámica 1234', 'pinned' => true], '2026-10-26T08:00:00Z'),
        N::op('note.upsert', ['id' => $this->archived, 'type' => 'text', 'title' => 'Antigua', 'body' => 'Cerámicas viejas', 'archived' => true], '2026-10-26T07:00:00Z'),
        N::op('note.upsert', ['id' => $this->trashed, 'type' => 'text', 'body' => 'Cerámica rota', 'deleted' => true]),
    ]);
});

it('finds notes ignoring accents with pinned notes first', function () {
    $response = $this->getJson('/api/v1/notes/search?q=ceramica')->assertOk();

    expect($response->json('data.*.id'))->toBe([$this->pinned, $this->tiles, $this->archived]);

    $response->assertJsonPath('data.1', [
        'id' => $this->tiles,
        'type' => 'text',
        'title' => 'Baño',
        'snippet' => 'La cerámica del suelo es gris',
        'folder_path' => ['Casa', 'Reformas'],
        'archived' => false,
        'updated_at' => '2026-10-26T09:00:00.000000Z',
    ])->assertJsonPath('data.0.folder_path', [])
        ->assertJsonPath('data.2.archived', true);
});

it('finds lists by their items and by prefixes', function () {
    $this->getJson('/api/v1/notes/search?q=JAMON')
        ->assertOk()
        ->assertJsonPath('data.0.id', $this->shopping)
        ->assertJsonPath('data.0.snippet', 'Jamón serrano, Jamón york');

    $this->getJson('/api/v1/notes/search?q=fontan')->assertOk()->assertJsonPath('data.0.id', $this->tiles);
    $this->getJson('/api/v1/notes/search?q=baño alicatado')->assertOk()->assertJsonPath('data.*.id', [$this->tiles]);
    $this->getJson('/api/v1/notes/search?q=1234')->assertOk()->assertJsonPath('data.*.id', [$this->pinned]);
});

it('handles queries with tsquery metacharacters and limits', function () {
    $this->getJson('/api/v1/notes/search?q='.rawurlencode("cerámica & | ! ( ) : * ' <->"))->assertOk()->assertJsonCount(3, 'data');
    $this->getJson('/api/v1/notes/search?q='.rawurlencode('&&&'))->assertOk()->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/notes/search?q=ceramica&limit=1')->assertOk()->assertJsonCount(1, 'data');
    $this->getJson('/api/v1/notes/search')->assertUnprocessable();
});

it('falls back to a substring match', function () {
    $this->getJson('/api/v1/notes/search?q=resupuest')->assertOk()->assertJsonPath('data.*.id', [$this->tiles]);
});

it('only searches the notes of the current user', function () {
    $other = User::factory()->create();
    $note = new Note(['type' => 'text', 'body' => 'Cerámica ajena']);
    $note->id = N::id();
    $note->user_id = $other->id;
    $note->save();

    expect($this->getJson('/api/v1/notes/search?q=ajena')->assertOk()->json('data'))->toBe([]);
});

it('contributes to the global search', function () {
    $results = collect($this->getJson('/api/v1/search?q=ceramica')->assertOk()->json('data'))->where('module', 'notes')->values();

    expect($results->all())->toHaveCount(3)
        ->and($results[1])->toBe([
            'module' => 'notes',
            'module_name' => 'Notas',
            'type' => 'note',
            'id' => $this->tiles,
            'title' => 'Baño',
            'subtitle' => 'Casa › Reformas',
            'url' => '/notas/n/'.$this->tiles,
            'icon' => 'notebook-pen',
        ])
        ->and($results[0]['subtitle'])->toBe('Texto');

    $shopping = collect($this->getJson('/api/v1/search?q=jamon')->assertOk()->json('data'))->firstWhere('module', 'notes');

    expect($shopping)->toMatchArray(['title' => 'Compra', 'subtitle' => 'Compra', 'icon' => 'shopping-cart']);

    $this->patchJson('/api/v1/modules/notes', ['enabled' => false])->assertOk();
    expect(collect($this->getJson('/api/v1/search?q=ceramica')->assertOk()->json('data'))->where('module', 'notes'))->toBeEmpty();
});
