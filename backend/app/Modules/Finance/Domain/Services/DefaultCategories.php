<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\CategoryKind;
use App\Modules\Finance\Models\Category;

final class DefaultCategories
{
    /**
     * @return list<array{name: string, icon: string, color: string, opens_period?: bool, children?: list<array{name: string, icon: string}>}>
     */
    public static function expense(): array
    {
        return [
            ['name' => 'Hogar', 'icon' => 'house', 'color' => 'c1', 'children' => [
                ['name' => 'Alquiler', 'icon' => 'key-round'],
                ['name' => 'Luz', 'icon' => 'zap'],
                ['name' => 'Agua', 'icon' => 'droplet'],
                ['name' => 'Gas', 'icon' => 'flame'],
                ['name' => 'Internet y móvil', 'icon' => 'wifi'],
                ['name' => 'Mantenimiento', 'icon' => 'wrench'],
            ]],
            ['name' => 'Alimentación', 'icon' => 'utensils', 'color' => 'c2', 'children' => [
                ['name' => 'Supermercado', 'icon' => 'shopping-cart'],
                ['name' => 'Restaurantes', 'icon' => 'utensils-crossed'],
                ['name' => 'Cafeterías', 'icon' => 'coffee'],
            ]],
            ['name' => 'Transporte', 'icon' => 'car', 'color' => 'c3', 'children' => [
                ['name' => 'Combustible', 'icon' => 'fuel'],
                ['name' => 'Transporte público', 'icon' => 'bus'],
                ['name' => 'Parking y peajes', 'icon' => 'square-parking'],
                ['name' => 'Taxi', 'icon' => 'car-taxi-front'],
                ['name' => 'Mantenimiento del coche', 'icon' => 'cog'],
            ]],
            ['name' => 'Ocio', 'icon' => 'party-popper', 'color' => 'c4', 'children' => [
                ['name' => 'Cine y espectáculos', 'icon' => 'clapperboard'],
                ['name' => 'Viajes', 'icon' => 'plane'],
                ['name' => 'Deporte', 'icon' => 'dumbbell'],
                ['name' => 'Aficiones', 'icon' => 'gamepad-2'],
            ]],
            ['name' => 'Salud', 'icon' => 'heart-pulse', 'color' => 'c5', 'children' => [
                ['name' => 'Farmacia', 'icon' => 'pill'],
                ['name' => 'Médico', 'icon' => 'stethoscope'],
                ['name' => 'Seguro médico', 'icon' => 'shield-plus'],
            ]],
            ['name' => 'Suscripciones', 'icon' => 'repeat', 'color' => 'c6', 'children' => [
                ['name' => 'Streaming', 'icon' => 'tv'],
                ['name' => 'Software', 'icon' => 'app-window'],
                ['name' => 'Gimnasio', 'icon' => 'dumbbell'],
            ]],
            ['name' => 'Ropa', 'icon' => 'shirt', 'color' => 'c7'],
            ['name' => 'Educación', 'icon' => 'graduation-cap', 'color' => 'c8', 'children' => [
                ['name' => 'Libros', 'icon' => 'book-open'],
                ['name' => 'Cursos', 'icon' => 'school'],
            ]],
            ['name' => 'Regalos', 'icon' => 'gift', 'color' => 'c1'],
            ['name' => 'Impuestos', 'icon' => 'landmark', 'color' => 'c2'],
            ['name' => 'Otros', 'icon' => 'circle-ellipsis', 'color' => 'c3'],
        ];
    }

    /**
     * @return list<array{name: string, icon: string, color: string, opens_period?: bool, children?: list<array{name: string, icon: string}>}>
     */
    public static function income(): array
    {
        return [
            ['name' => 'Nómina', 'icon' => 'briefcase', 'color' => 'c1', 'opens_period' => true],
            ['name' => 'Extra', 'icon' => 'sparkles', 'color' => 'c2'],
            ['name' => 'Reembolsos', 'icon' => 'rotate-ccw', 'color' => 'c3'],
            ['name' => 'Intereses', 'icon' => 'percent', 'color' => 'c4'],
        ];
    }

    public function seedFor(User $user): void
    {
        if (Category::query()->ownedBy($user)->exists()) {
            return;
        }

        foreach ([CategoryKind::Expense->value => self::expense(), CategoryKind::Income->value => self::income()] as $kind => $definitions) {
            foreach ($definitions as $position => $definition) {
                $parent = $this->create($user, $kind, $definition['name'], $definition['icon'], $definition['color'], $position, null, $definition['opens_period'] ?? false);

                foreach ($definition['children'] ?? [] as $childPosition => $child) {
                    $this->create($user, $kind, $child['name'], $child['icon'], null, $childPosition, $parent->id, false);
                }
            }
        }
    }

    private function create(User $user, string $kind, string $name, string $icon, ?string $color, int $position, ?string $parentId, bool $opensPeriod): Category
    {
        $category = new Category([
            'name' => $name,
            'kind' => $kind,
            'icon' => $icon,
            'color' => $color,
            'sort_order' => $position,
            'parent_id' => $parentId,
            'opens_period' => $opensPeriod,
        ]);
        $category->user_id = $user->id;
        $category->save();

        return $category;
    }
}
