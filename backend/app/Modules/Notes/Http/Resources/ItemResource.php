<?php

namespace App\Modules\Notes\Http\Resources;

use App\Modules\Notes\Models\NoteItem;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin NoteItem
 */
final class ItemResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var NoteItem $item */
        $item = $this->resource;

        return [
            'id' => $item->id,
            'note_id' => $item->note_id,
            'product_id' => $item->product_id,
            'text' => $item->text,
            'quantity' => $item->quantity,
            'section_id' => $item->section_id,
            'checked_at' => $item->checked_at?->toJSON(),
            'position' => $item->position,
            'updated_at' => $item->updated_at?->toJSON(),
        ];
    }
}
