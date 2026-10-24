<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Category
 */
final class CategoryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Category $category */
        $category = $this->resource;

        return [
            'id' => $category->id,
            'name' => $category->name,
            'kind' => $category->kind->value,
            'parent_id' => $category->parent_id,
            'icon' => $category->icon,
            'color' => $category->color,
            'sort_order' => $category->sort_order,
            'opens_period' => $category->opens_period,
            'archived' => $category->archived_at !== null,
            'children' => $this->when(
                $category->parent_id === null && $category->relationLoaded('children'),
                fn () => CategoryResource::collection($category->children)->resolve($request),
            ),
        ];
    }
}
