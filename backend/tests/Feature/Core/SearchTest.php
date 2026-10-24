<?php

use App\Core\Search\ModuleSearcher;
use App\Models\User;
use Tests\Feature\Core\Fixtures\Journal\JournalModule;
use Tests\Feature\Core\Fixtures\Journal\JournalSearcher;

beforeEach(fn () => JournalModule::register($this->app));

it('returns an empty list when no searcher matches', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->getJson('/api/v1/search?q=mercadona')
        ->assertOk()
        ->assertExactJson(['data' => []]);
});

it('aggregates results from tagged module searchers', function () {
    $this->app->tag([JournalSearcher::class], ModuleSearcher::TAG);
    $user = User::factory()->create();

    $this->actingAs($user)->getJson('/api/v1/search?q=viaje&limit=3')
        ->assertOk()
        ->assertJsonCount(3, 'data')
        ->assertJsonPath('data.0', [
            'module' => 'journal',
            'module_name' => 'Diario',
            'type' => 'entry',
            'id' => 'entry-1',
            'title' => 'Entrada 1: viaje',
            'subtitle' => 'Hoy',
            'url' => '/diario/1',
            'icon' => 'book',
        ]);
});

it('skips searchers of disabled modules', function () {
    $this->app->tag([JournalSearcher::class], ModuleSearcher::TAG);
    $user = User::factory()->create();
    $user->moduleSettings()->create(['module_id' => 'journal', 'enabled' => false]);

    $this->actingAs($user)->getJson('/api/v1/search?q=viaje')
        ->assertOk()
        ->assertExactJson(['data' => []]);
});

it('validates the query', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->getJson('/api/v1/search?q=a')
        ->assertUnprocessable()
        ->assertJsonValidationErrors('q');
});
