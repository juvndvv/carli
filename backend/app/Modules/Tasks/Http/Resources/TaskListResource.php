<?php

namespace App\Modules\Tasks\Http\Resources;

use App\Modules\Tasks\Models\TaskList;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin TaskList
 */
final class TaskListResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var TaskList $list */
        $list = $this->resource;

        return [
            'id' => $list->id,
            'name' => $list->name,
            'color' => $list->color,
            'icon' => $list->icon,
            'is_default' => $list->is_default,
            'sort_order' => $list->sort_order,
            'archived' => $list->archived_at !== null,
            'open_tasks_count' => $this->when($list->open_tasks_count !== null, fn () => (int) $list->open_tasks_count),
            'created_at' => $list->created_at?->toIso8601String(),
            'updated_at' => $list->updated_at?->toIso8601String(),
        ];
    }
}
