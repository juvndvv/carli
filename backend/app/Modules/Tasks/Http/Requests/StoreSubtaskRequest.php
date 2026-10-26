<?php

namespace App\Modules\Tasks\Http\Requests;

final class StoreSubtaskRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'title' => [$required, 'string', 'max:255'],
            'done' => ['sometimes', 'boolean'],
            'sort' => ['sometimes', 'integer'],
        ];
    }
}
