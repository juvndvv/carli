<?php

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use App\Modules\Finance\FinanceServiceProvider;
use Illuminate\Support\Facades\Route;
use Tests\Feature\Core\Fixtures\Journal\JournalModule;

beforeEach(fn () => JournalModule::register($this->app));

it('lists available modules followed by coming soon placeholders', function () {
    $user = User::factory()->create();

    $response = $this->actingAs($user)->getJson('/api/v1/modules')->assertOk();

    expect($response->json('data.*.id'))->toBe(['journal', 'tasks', 'health', 'habits', 'notes']);

    $response->assertJsonPath('data.0', [
        'id' => 'journal',
        'name' => 'Diario',
        'icon' => 'book',
        'route' => '/diario',
        'description' => null,
        'available' => true,
        'coming_soon' => false,
        'enabled' => true,
        'settings' => ['reminder_hour' => 21],
    ]);

    $response->assertJsonPath('data.1.available', false)
        ->assertJsonPath('data.1.coming_soon', true)
        ->assertJsonPath('data.1.enabled', false)
        ->assertJsonPath('data.1.name', 'Tareas');
});

it('disables a module and merges its settings', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->patchJson('/api/v1/modules/journal', ['enabled' => false, 'settings' => ['theme' => 'paper']])
        ->assertOk()
        ->assertJsonPath('data.enabled', false)
        ->assertJsonPath('data.settings', ['reminder_hour' => 21, 'theme' => 'paper']);

    $this->actingAs($user)->patchJson('/api/v1/modules/journal', ['settings' => ['reminder_hour' => 8]])
        ->assertOk()
        ->assertJsonPath('data.enabled', false)
        ->assertJsonPath('data.settings', ['reminder_hour' => 8, 'theme' => 'paper']);

    expect(app(ModuleRegistry::class)->isEnabledFor($user, 'journal'))->toBeFalse();

    $this->actingAs($user)->patchJson('/api/v1/modules/journal', ['enabled' => true])
        ->assertJsonPath('data.enabled', true);
});

it('keeps module state per user', function () {
    $user = User::factory()->create();
    $other = User::factory()->create();

    $this->actingAs($user)->patchJson('/api/v1/modules/journal', ['enabled' => false])->assertOk();

    expect(app(ModuleRegistry::class)->isEnabledFor($other, 'journal'))->toBeTrue();
});

it('rejects unknown and coming soon modules', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->patchJson('/api/v1/modules/unknown', ['enabled' => true])->assertNotFound();
    $this->actingAs($user)->patchJson('/api/v1/modules/tasks', ['enabled' => true])->assertUnprocessable();
});

it('blocks module routes when the module is disabled', function () {
    Route::middleware(['api', 'auth:sanctum', 'module:journal'])->get('/api/v1/journal/ping', fn () => ['ok' => true]);

    $user = User::factory()->create();

    $this->actingAs($user)->getJson('/api/v1/journal/ping')->assertOk();

    $this->actingAs($user)->patchJson('/api/v1/modules/journal', ['enabled' => false])->assertOk();

    $this->actingAs($user)->getJson('/api/v1/journal/ping')->assertForbidden();
});

it('reads the finance manifest from the configured providers', function () {
    $this->app->forgetInstance(ModuleRegistry::class);
    $this->app->singleton(ModuleRegistry::class, fn () => new ModuleRegistry([FinanceServiceProvider::class]));

    $manifestPath = dirname((string) (new ReflectionClass(FinanceServiceProvider::class))->getFileName()).'/module.php';

    if (! is_file($manifestPath)) {
        $this->markTestSkipped('The finance module manifest is not available yet.');
    }

    $finance = app(ModuleRegistry::class)->find('finance');

    expect($finance)->not->toBeNull()
        ->and($finance->available)->toBeTrue()
        ->and($finance->name)->toBe('Finanzas')
        ->and(array_keys($finance->notifications))->toContain(
            'budget_threshold', 'upcoming_charge', 'recurring_pending', 'goal_reached', 'debt_reminder', 'payroll_overdue', 'weekly_summary',
        );
});
