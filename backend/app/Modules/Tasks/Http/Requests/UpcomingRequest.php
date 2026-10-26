<?php

namespace App\Modules\Tasks\Http\Requests;

final class UpcomingRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'days' => ['sometimes', 'integer', 'between:1,62'],
        ];
    }
}
