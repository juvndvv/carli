<?php

namespace App\Modules\Habits\Http\Resources;

use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Models\HabitBreak;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin HabitBreak
 */
final class BreakResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var HabitBreak $break */
        $break = $this->resource;
        $today = HabitCalendar::today();

        return [
            'id' => $break->id,
            'habit_id' => $break->habit_id,
            'from_date' => $break->from_date->toDateString(),
            'to_date' => $break->to_date->toDateString(),
            'active' => $break->covers($today),
            'upcoming' => $break->from_date->gt($today),
        ];
    }
}
