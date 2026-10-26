<?php

namespace App\Modules\Notes\Http\Resources;

use App\Modules\Notes\Models\ShoppingSection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ShoppingSection
 */
final class SectionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var ShoppingSection $section */
        $section = $this->resource;

        return [
            'id' => $section->id,
            'name' => $section->name,
            'position' => $section->position,
            'updated_at' => $section->updated_at?->toJSON(),
        ];
    }
}
