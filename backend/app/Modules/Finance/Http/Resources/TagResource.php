<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Models\Tag;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Tag
 */
final class TagResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Tag $tag */
        $tag = $this->resource;

        return [
            'id' => $tag->id,
            'name' => $tag->name,
            'color' => $tag->color,
            'transactions_count' => (int) ($tag->transactions_count ?? $tag->transactions()->count()),
        ];
    }
}
