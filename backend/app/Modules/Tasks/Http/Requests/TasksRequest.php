<?php

namespace App\Modules\Tasks\Http\Requests;

use App\Models\User;
use App\Modules\Tasks\Models\TaskList;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

abstract class TasksRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function tasksUser(): User
    {
        $user = $this->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }

    /**
     * @return list<mixed>
     */
    protected function ownedList(bool $required = false): array
    {
        return [$required ? 'required' : 'sometimes', 'bail', 'uuid', Rule::exists(TaskList::class, 'id')->where('user_id', $this->tasksUser()->id)->whereNull('archived_at')];
    }

    /**
     * @return list<string>
     */
    protected function time(): array
    {
        return ['sometimes', 'nullable', 'date_format:H:i'];
    }
}
