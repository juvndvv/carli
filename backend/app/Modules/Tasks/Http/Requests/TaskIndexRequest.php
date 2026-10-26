<?php

namespace App\Modules\Tasks\Http\Requests;

use Illuminate\Validation\Rule;

final class TaskIndexRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'list_id' => ['sometimes', 'uuid'],
            'status' => ['sometimes', Rule::in(['open', 'done', 'all'])],
            'q' => ['sometimes', 'nullable', 'string', 'max:100'],
            'from' => ['sometimes', 'date_format:Y-m-d'],
            'to' => ['sometimes', 'date_format:Y-m-d'],
            'page' => ['sometimes', 'integer', 'min:1'],
        ];
    }
}
