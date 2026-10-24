<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\CategoryKind;
use App\Modules\Finance\Models\Budget;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Models\TransactionSplit;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class CategoryService
{
    public function __construct(private readonly PeriodService $periods) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data): Category
    {
        $category = new Category;
        $category->user_id = $user->id;
        $category->fill($this->attributes($data));
        $this->assertValid($category);
        $category->sort_order = (int) ($data['sort_order'] ?? ((int) Category::query()->ownedBy($user)
            ->where('kind', $category->kind->value)
            ->where('parent_id', $category->parent_id)
            ->max('sort_order') + 1));
        $category->save();

        return $category;
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Category $category, array $data): Category
    {
        $opensPeriodBefore = $category->opens_period;
        $category->fill($this->attributes($data));

        if (array_key_exists('archived', $data)) {
            $category->archived_at = $data['archived'] ? ($category->archived_at ?? CarbonImmutable::now()) : null;
        }

        if ($category->isDirty('kind') && $this->isInUse($this->withChildren($category))) {
            throw ValidationException::withMessages(['kind' => 'No puedes cambiar el tipo de una categoría (o sus subcategorías) con movimientos, presupuestos o recurrentes.']);
        }

        $this->assertValid($category);

        DB::transaction(function () use ($category, $opensPeriodBefore): void {
            $category->save();

            if ($category->parent_id === null && $category->wasChanged('kind')) {
                Category::query()->ownedBy($category->user_id)->where('parent_id', $category->id)->update(['kind' => $category->kind->value]);
            }

            if ($opensPeriodBefore !== $category->opens_period) {
                $this->periods->rebuild($category->user_id);
            }
        });

        return $category;
    }

    public function delete(Category $category, ?string $reassignTo): void
    {
        if (Category::query()->ownedBy($category->user_id)->where('parent_id', $category->id)->exists()) {
            throw ValidationException::withMessages(['category' => 'Elimina o mueve primero sus subcategorías.']);
        }

        $referenced = $this->isReferenced([$category->id]);

        if ($referenced && $reassignTo === null) {
            throw ValidationException::withMessages([
                'reassign_to' => 'La categoría tiene movimientos: elige otra categoría a la que reasignarlos.',
            ]);
        }

        $target = null;
        if ($reassignTo !== null) {
            $target = Category::query()->ownedBy($category->user_id)->whereKey($reassignTo)->first();

            if ($target === null || $target->is($category)) {
                throw ValidationException::withMessages(['reassign_to' => 'La categoría de destino no es válida.']);
            }

            if ($target->kind !== $category->kind) {
                throw ValidationException::withMessages(['reassign_to' => 'La categoría de destino debe ser del mismo tipo.']);
            }
        }

        DB::transaction(function () use ($category, $target): void {
            if ($target !== null) {
                Transaction::query()->withoutGlobalScopes()->withTrashed()->where('category_id', $category->id)->update(['category_id' => $target->id]);
                TransactionSplit::query()->where('category_id', $category->id)->update(['category_id' => $target->id]);
                RecurringRule::query()->withoutGlobalScopes()->where('category_id', $category->id)->update(['category_id' => $target->id]);
                $this->mergeBudgets($category, $target);
            }

            $opensPeriod = $category->opens_period;
            $category->delete();

            if ($opensPeriod) {
                $this->periods->rebuild($category->user_id);
            }
        });
    }

    /**
     * @param  list<string>  $categoryIds
     */
    public function isReferenced(array $categoryIds): bool
    {
        return Transaction::query()->withoutGlobalScopes()->withTrashed()->whereIn('category_id', $categoryIds)->exists()
            || TransactionSplit::query()->whereIn('category_id', $categoryIds)->exists();
    }

    /**
     * @return list<string>
     */
    private function withChildren(Category $category): array
    {
        $childIds = Category::query()->ownedBy($category->user_id)->where('parent_id', $category->id)->pluck('id')->all();

        return [$category->id, ...array_values(array_map('strval', $childIds))];
    }

    /**
     * @param  list<string>  $categoryIds
     */
    private function isInUse(array $categoryIds): bool
    {
        return $this->isReferenced($categoryIds)
            || Budget::query()->withoutGlobalScopes()->whereIn('category_id', $categoryIds)->exists()
            || RecurringRule::query()->withoutGlobalScopes()->whereIn('category_id', $categoryIds)->exists();
    }

    public function transactionsCount(Category $category): int
    {
        return Transaction::query()->withoutGlobalScopes()->where('category_id', $category->id)->count()
            + TransactionSplit::query()->where('category_id', $category->id)->count();
    }

    private function mergeBudgets(Category $source, Category $target): void
    {
        foreach (Budget::query()->ownedBy($source->user_id)->where('category_id', $source->id)->get() as $budget) {
            $existing = Budget::query()->ownedBy($source->user_id)
                ->where('category_id', $target->id)
                ->where('period_id', $budget->period_id)
                ->first();

            if ($existing === null) {
                $budget->category_id = $target->id;
                $budget->save();

                continue;
            }

            $existing->amount_cents += $budget->amount_cents;
            $existing->save();
            $budget->delete();
        }
    }

    private function assertValid(Category $category): void
    {
        if ($category->parent_id !== null) {
            $parent = Category::query()->ownedBy($category->user_id)->whereKey($category->parent_id)->first();

            if ($parent === null || $parent->parent_id !== null || $parent->is($category)) {
                throw ValidationException::withMessages(['parent_id' => 'Las categorías solo admiten dos niveles.']);
            }

            if ($category->exists && Category::query()->ownedBy($category->user_id)->where('parent_id', $category->id)->exists()) {
                throw ValidationException::withMessages(['parent_id' => 'Una categoría con subcategorías no puede ser subcategoría.']);
            }

            $category->kind = $parent->kind;
        }

        if ($category->opens_period && $category->kind !== CategoryKind::Income) {
            throw ValidationException::withMessages(['opens_period' => 'Solo las categorías de ingreso pueden abrir periodo.']);
        }

        $duplicate = Category::query()->ownedBy($category->user_id)
            ->where('name', $category->name)
            ->where('parent_id', $category->parent_id);

        if ($category->exists) {
            $duplicate->whereKeyNot($category->id);
        }

        if ($duplicate->exists()) {
            throw ValidationException::withMessages(['name' => 'Ya existe una categoría con ese nombre en ese nivel.']);
        }
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data): array
    {
        return array_intersect_key($data, array_flip(['name', 'kind', 'parent_id', 'icon', 'color', 'sort_order', 'opens_period']));
    }
}
