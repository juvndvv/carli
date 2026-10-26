<?php

namespace App\Modules\Notes\Http\Resources;

use App\Modules\Notes\Models\Note;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Note
 */
final class NoteResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Note $note */
        $note = $this->resource;

        return [
            'id' => $note->id,
            'folder_id' => $note->folder_id,
            'type' => $note->type->value,
            'title' => $note->title,
            'body' => $note->body,
            'pinned_at' => $note->pinned_at?->toJSON(),
            'archived_at' => $note->archived_at?->toJSON(),
            'deleted_at' => $note->deleted_at?->toJSON(),
            'checked_behavior' => $note->checked_behavior->value,
            'is_primary' => $note->is_primary,
            'sort' => $note->sort,
            'created_at' => $note->created_at?->toJSON(),
            'updated_at' => $note->updated_at?->toJSON(),
            'items' => ItemResource::collection($note->items)->resolve($request),
        ];
    }
}
