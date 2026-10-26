<?php

namespace App\Modules\Notes\Http\Resources;

use App\Modules\Notes\Models\ShoppingProduct;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ShoppingProduct
 */
final class ProductResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var ShoppingProduct $product */
        $product = $this->resource;

        return [
            'id' => $product->id,
            'note_id' => $product->note_id,
            'name' => $product->name,
            'section_id' => $product->section_id,
            'default_quantity' => $product->default_quantity,
            'restock_mode' => $product->restock_mode->value,
            'restock_interval_days' => $product->restock_interval_days,
            'last_bought_at' => $product->last_bought_at?->toJSON(),
            'times_bought' => $product->times_bought,
            'restocked_for' => $product->restocked_for,
            'updated_at' => $product->updated_at?->toJSON(),
        ];
    }
}
