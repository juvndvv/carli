<?php

namespace App\Modules\Habits\Domain\Services;

use App\Models\User;
use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Evaluation\Goal;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Models\Habit;
use App\Modules\Habits\Models\HabitBreak;
use App\Modules\Habits\Models\HabitGoal;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class HabitService
{
    private const array ATTRIBUTES = ['name', 'icon', 'unit', 'show_in_tasks', 'start_date', 'preferred_time'];

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data): Habit
    {
        return DB::transaction(function () use ($user, $data): Habit {
            $habit = new Habit($this->attributes($data) + ['start_date' => HabitCalendar::today()->toDateString()]);
            $habit->kind = HabitKind::from((string) $data['kind']);
            $habit->user_id = $user->id;
            $habit->sort = (int) Habit::query()->ownedBy($user)->max('sort') + 1;
            $habit->converted_from_template_id = isset($data['converted_from_template_id']) ? (string) $data['converted_from_template_id'] : null;
            $habit->save();

            $habit->goals()->create($this->goalAttributes($data, $habit->kind) + ['valid_from' => $habit->start_date->toDateString()]);

            return $habit->load('goals');
        });
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Habit $habit, array $data): Habit
    {
        return DB::transaction(function () use ($habit, $data): Habit {
            $habit->fill($this->attributes($data));
            $habit->save();

            if (array_intersect_key($data, array_flip(['period', 'target', 'days_of_week'])) !== []) {
                $this->changeGoal($habit, $data);
            }

            return $habit->load('goals');
        });
    }

    public function pause(Habit $habit): Habit
    {
        $habit->paused_at ??= now()->toImmutable();
        $habit->save();

        return $habit;
    }

    public function resume(Habit $habit): Habit
    {
        return $this->restart($habit, 'paused_at');
    }

    public function archive(Habit $habit): Habit
    {
        $habit->archived_at ??= now()->toImmutable();
        $habit->save();

        return $habit;
    }

    public function unarchive(Habit $habit): Habit
    {
        return $this->restart($habit, 'archived_at');
    }

    public function delete(Habit $habit): void
    {
        $habit->delete();
    }

    /**
     * @param  list<string>  $ids
     */
    public function reorder(User $user, array $ids): void
    {
        DB::transaction(function () use ($user, $ids): void {
            foreach ($ids as $index => $id) {
                Habit::query()->ownedBy($user)->whereKey($id)->update(['sort' => $index + 1]);
            }
        });
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function changeGoal(Habit $habit, array $data): void
    {
        $current = $habit->currentGoal();
        $merged = $this->goalAttributes($data + [
            'period' => $current->period->value,
            'target' => $current->target,
            'days_of_week' => $current->days_of_week,
        ], $habit->kind);

        $next = new Goal(HabitCalendar::today(), GoalPeriod::from($merged['period']), $merged['target'], $merged['days_of_week']);

        if ($next->sameAs(Goal::fromModel($current))) {
            return;
        }

        $validFrom = HabitCalendar::today()->max($habit->start_date)->toDateString();
        $habit->goals()->where('valid_from', '>', $validFrom)->delete();
        HabitGoal::query()->updateOrCreate(['habit_id' => $habit->id, 'valid_from' => $validFrom], $merged);
    }

    private function restart(Habit $habit, string $column): Habit
    {
        return DB::transaction(function () use ($habit, $column): Habit {
            $stopped = $habit->stoppedOn();
            $yesterday = HabitCalendar::today()->subDay();
            $habit->setAttribute($column, null);
            $stillStopped = $habit->stoppedOn() !== null;

            if ($stopped !== null && ! $stillStopped && $stopped->lte($yesterday)) {
                $this->breakFor($habit, $stopped->max($habit->start_date), $yesterday);
            }

            $habit->save();

            return $habit;
        });
    }

    private function breakFor(Habit $habit, CarbonImmutable $from, CarbonImmutable $to): void
    {
        if ($to->lt($from)) {
            return;
        }

        $break = new HabitBreak(['habit_id' => $habit->id, 'from_date' => $from->toDateString(), 'to_date' => $to->toDateString()]);
        $break->user_id = $habit->user_id;
        $break->save();
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data): array
    {
        $attributes = array_intersect_key($data, array_flip(self::ATTRIBUTES));

        foreach (['name', 'unit'] as $key) {
            if (isset($attributes[$key]) && is_string($attributes[$key])) {
                $attributes[$key] = trim($attributes[$key]) === '' && $key === 'unit' ? null : trim($attributes[$key]);
            }
        }

        return $attributes;
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array{period: string, target: float, days_of_week: list<int>|null}
     */
    private function goalAttributes(array $data, HabitKind $kind): array
    {
        $period = GoalPeriod::tryFrom((string) ($data['period'] ?? '')) ?? GoalPeriod::Day;
        $target = (float) ($data['target'] ?? ($kind === HabitKind::Avoid ? 0 : 1));
        $days = $data['days_of_week'] ?? null;

        if ($kind === HabitKind::Check && $period === GoalPeriod::Day) {
            $target = 1.0;
        }

        if ($period === GoalPeriod::Week || ! is_array($days) || $days === []) {
            $days = null;
        } else {
            $days = array_values(array_unique(array_map(intval(...), $days)));
            sort($days);
            $days = count($days) === 7 ? null : $days;
        }

        return ['period' => $period->value, 'target' => $target, 'days_of_week' => $days];
    }
}
