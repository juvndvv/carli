<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Models\CategoryRule;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin CategoryRule
 */
final class CategoryRuleResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var CategoryRule $rule */
        $rule = $this->resource;
        $rule->loadMissing('category.parent');

        return [
            'id' => $rule->id,
            'pattern' => $rule->pattern,
            'kind' => $rule->kind->value,
            'category_id' => $rule->category_id,
            'category' => CategorySummary::of($rule->category),
            'created_at' => $rule->created_at?->toIso8601String(),
            'updated_at' => $rule->updated_at?->toIso8601String(),
        ];
    }
}
