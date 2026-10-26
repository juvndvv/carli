<?php

namespace App\Modules\Tasks\Http\Requests;

final class StoreTaskListRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name' => [$required, 'string', 'max:80'],
            'color' => ['sometimes', 'nullable', 'string', 'max:32'],
            'icon' => ['sometimes', 'nullable', 'string', 'max:64'],
            'archived' => ['sometimes', 'boolean'],
        ];
    }
}
