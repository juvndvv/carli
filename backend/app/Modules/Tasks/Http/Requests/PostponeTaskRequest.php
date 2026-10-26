<?php

namespace App\Modules\Tasks\Http\Requests;

final class PostponeTaskRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'date' => ['required', 'date_format:Y-m-d'],
        ];
    }
}
