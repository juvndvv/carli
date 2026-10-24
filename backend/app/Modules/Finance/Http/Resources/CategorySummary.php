<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Models\Category;

final class CategorySummary
{
    /**
     * @return array{id: string, name: string, parent: string|null, parent_id: string|null, icon: string|null, color: string|null, kind: string}|null
     */
    public static function of(?Category $category): ?array
    {
        if ($category === null) {
            return null;
        }

        return [
            'id' => $category->id,
            'name' => $category->name,
            'parent' => $category->parent?->name,
            'parent_id' => $category->parent_id,
            'icon' => $category->icon ?? $category->parent?->icon,
            'color' => $category->color ?? $category->parent?->color,
            'kind' => $category->kind->value,
        ];
    }
}
