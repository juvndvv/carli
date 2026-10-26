<?php

namespace App\Modules\Notes\Http\Resources;

use App\Modules\Notes\Models\Folder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Folder
 */
final class FolderResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Folder $folder */
        $folder = $this->resource;

        return [
            'id' => $folder->id,
            'parent_id' => $folder->parent_id,
            'name' => $folder->name,
            'position' => $folder->position,
            'created_at' => $folder->created_at?->toJSON(),
            'updated_at' => $folder->updated_at?->toJSON(),
        ];
    }
}
