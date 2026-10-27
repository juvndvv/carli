<?php

namespace App\Modules\Habits\Domain\Services;

use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Models\HabitBreak;

final class BreakService
{
    /**
     * @param  array{from_date: string, to_date: string, habit_id?: string|null}  $data
     */
    public function create(User $user, array $data): HabitBreak
    {
        $break = new HabitBreak([
            'habit_id' => $data['habit_id'] ?? null,
            'from_date' => $data['from_date'],
            'to_date' => $data['to_date'],
        ]);
        $break->user_id = $user->id;
        $break->save();

        return $break;
    }

    /**
     * @param  array{from_date?: string, to_date?: string}  $data
     */
    public function update(HabitBreak $break, array $data): HabitBreak
    {
        $break->fill($data);
        $break->save();

        return $break;
    }

    public function end(HabitBreak $break): ?HabitBreak
    {
        $yesterday = HabitCalendar::today()->subDay();

        if ($break->from_date->gt($yesterday)) {
            $break->delete();

            return null;
        }

        $break->to_date = $break->to_date->min($yesterday);
        $break->save();

        return $break;
    }
}
