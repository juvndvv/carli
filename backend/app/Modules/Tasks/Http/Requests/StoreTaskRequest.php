<?php

namespace App\Modules\Tasks\Http\Requests;

final class StoreTaskRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('POST');

        return [
            'title' => [$creating ? 'required' : 'sometimes', 'string', 'max:255'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:10000'],
            'list_id' => $this->ownedList(),
            'due_date' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'due_time' => $this->time(),
            'important' => ['sometimes', 'boolean'],
            'sort' => ['sometimes', 'integer'],
            'subtasks' => $creating ? ['sometimes', 'array', 'max:50'] : ['prohibited'],
            'subtasks.*' => ['string', 'max:255'],
        ];
    }
}
