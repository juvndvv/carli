<?php

namespace App\Modules\Tasks\Http\Resources;

use App\Modules\Tasks\Models\TaskSubtask;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin TaskSubtask
 */
final class SubtaskResource extends JsonResource
{
    /**
     * @return array{id: string, title: string, done: bool, sort: int}
     */
    public static function present(TaskSubtask $subtask): array
    {
        return [
            'id' => $subtask->id,
            'title' => $subtask->title,
            'done' => $subtask->done_at !== null,
            'sort' => $subtask->sort,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var TaskSubtask $subtask */
        $subtask = $this->resource;

        return self::present($subtask);
    }
}
