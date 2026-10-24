<?php

use App\Models\User;
use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Budget;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
});

it('seeds the default Spanish categories on first access', function () {
    $user = User::factory()->create();
    expect(Category::query()->withoutGlobalScopes()->where('user_id', $user->id)->count())->toBe(0);

    $response = $this->actingAs($user)->getJson('/api/v1/finance/categories')->assertOk();
    $names = array_column($response->json('data'), 'name');

    expect($names)->toContain('Hogar', 'Alimentación', 'Transporte', 'Ocio', 'Salud', 'Suscripciones', 'Ropa', 'Educación', 'Regalos', 'Impuestos', 'Otros', 'Nómina', 'Extra', 'Reembolsos', 'Intereses');

    $payroll = collect($response->json('data'))->firstWhere('name', 'Nómina');
    $food = collect($response->json('data'))->firstWhere('name', 'Alimentación');
    expect($payroll['opens_period'])->toBeTrue()
        ->and($payroll['kind'])->toBe('income')
        ->and(array_column($food['children'], 'name'))->toContain('Supermercado')
        ->and($food['icon'])->toBe('utensils');

    $this->actingAs($user)->getJson('/api/v1/finance/categories')->assertOk();
    expect(Category::query()->withoutGlobalScopes()->where('user_id', $user->id)->where('name', 'Hogar')->count())->toBe(1);

    $this->actingAs($user)->getJson('/api/v1/finance/categories?flat=1&kind=income')->assertJsonCount(4, 'data');
});

it('enforces two levels and matching kinds', function () {
    $user = F::user();
    $this->actingAs($user);
    $supermarket = F::category($user, 'Supermercado');

    $this->postJson('/api/v1/finance/categories', ['name' => 'Ecológico', 'parent_id' => $supermarket->id])->assertUnprocessable();

    $this->postJson('/api/v1/finance/categories', ['name' => 'Mascotas', 'kind' => 'expense', 'icon' => 'paw-print'])
        ->assertCreated()
        ->assertJsonPath('data.kind', 'expense');

    $this->postJson('/api/v1/finance/categories', ['name' => 'Veterinario', 'parent_id' => F::category($user, 'Mascotas')->id, 'kind' => 'income'])
        ->assertCreated()
        ->assertJsonPath('data.kind', 'expense');

    $this->postJson('/api/v1/finance/categories', ['name' => 'Hogar', 'kind' => 'expense'])->assertUnprocessable();
    $this->postJson('/api/v1/finance/categories', ['name' => 'Bonus', 'kind' => 'expense', 'opens_period' => true])->assertUnprocessable();
});

it('requires reassigning movements when deleting a category', function () {
    $user = F::user();
    $this->actingAs($user);
    $account = F::account($user);
    $cafes = F::category($user, 'Cafeterías');
    $restaurants = F::category($user, 'Restaurantes');
    $transaction = F::expense($user, $account, 300, '2026-10-20', 'Cafeterías');

    $period = app(PeriodService::class)->current($user);
    app(BudgetService::class)->upsert($period, [['category_id' => $cafes->id, 'amount_cents' => 2000]]);

    $this->deleteJson("/api/v1/finance/categories/{$cafes->id}")->assertUnprocessable()->assertJsonValidationErrors('reassign_to');
    $this->deleteJson("/api/v1/finance/categories/{$cafes->id}?reassign_to=".F::category($user, 'Nómina')->id)->assertUnprocessable();
    $this->deleteJson('/api/v1/finance/categories/'.F::category($user, 'Alimentación')->id)->assertUnprocessable();

    $this->deleteJson("/api/v1/finance/categories/{$cafes->id}?reassign_to={$restaurants->id}")->assertNoContent();

    expect($transaction->refresh()->category_id)->toBe($restaurants->id)
        ->and(Budget::query()->where('category_id', $restaurants->id)->value('amount_cents'))->toBe(2000)
        ->and(Category::query()->whereKey($cafes->id)->exists())->toBeFalse();

    $this->deleteJson('/api/v1/finance/categories/'.F::category($user, 'Gas')->id)->assertNoContent();
});

it('refuses to change the kind of a parent whose subcategories are in use', function () {
    $user = F::user();
    $this->actingAs($user);
    $parent = $this->postJson('/api/v1/finance/categories', ['name' => 'Mascotas', 'kind' => 'expense'])->assertCreated()->json('data.id');
    $child = $this->postJson('/api/v1/finance/categories', ['name' => 'Veterinario', 'parent_id' => $parent])->assertCreated()->json('data.id');
    $empty = $this->postJson('/api/v1/finance/categories', ['name' => 'Varios', 'kind' => 'expense'])->assertCreated()->json('data.id');

    F::expense($user, F::account($user), 4500, '2026-10-20', 'Veterinario');

    $this->patchJson("/api/v1/finance/categories/{$parent}", ['kind' => 'income'])->assertUnprocessable()->assertJsonValidationErrors('kind');
    expect(Category::query()->whereKey($child)->firstOrFail()->kind->value)->toBe('expense');

    $this->patchJson("/api/v1/finance/categories/{$empty}", ['kind' => 'income'])->assertOk()->assertJsonPath('data.kind', 'income');
});
