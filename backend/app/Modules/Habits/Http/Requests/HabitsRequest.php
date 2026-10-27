<?php

namespace App\Modules\Habits\Http\Requests;

use App\Models\User;
use App\Modules\Habits\Models\Habit;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

abstract class HabitsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function habitsUser(): User
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
    protected function ownedHabit(): array
    {
        return ['sometimes', 'nullable', 'bail', 'uuid', Rule::exists(Habit::class, 'id')->where('user_id', $this->habitsUser()->id)];
    }
}
