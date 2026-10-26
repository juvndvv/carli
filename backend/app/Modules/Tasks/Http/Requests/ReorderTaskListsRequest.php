<?php

namespace App\Modules\Tasks\Http\Requests;

final class ReorderTaskListsRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'ids' => ['required', 'array', 'max:200'],
            'ids.*' => ['uuid'],
        ];
    }
}
