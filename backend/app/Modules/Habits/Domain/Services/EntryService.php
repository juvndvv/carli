<?php

namespace App\Modules\Habits\Domain\Services;

use App\Modules\Habits\Domain\Enums\EntrySource;
use App\Modules\Habits\Models\Habit;
use App\Modules\Habits\Models\HabitEntry;
use Carbon\CarbonImmutable;

final class EntryService
{
    public function set(Habit $habit, CarbonImmutable $date, float $value, ?string $note = null, EntrySource $source = EntrySource::Manual): ?HabitEntry
    {
        $note = $note === null || trim($note) === '' ? null : trim($note);

        if ($value <= 0 && $note === null) {
            $this->delete($habit, $date);

            return null;
        }

        $entry = HabitEntry::query()->updateOrCreate(
            ['habit_id' => $habit->id, 'date' => $date->toDateString()],
            ['value' => $value, 'note' => $note, 'source' => $source->value],
        );
        $habit->unsetRelation('entries');

        return $entry;
    }

    public function delete(Habit $habit, CarbonImmutable $date): void
    {
        $habit->entries()->whereDate('date', $date->toDateString())->delete();
        $habit->unsetRelation('entries');
    }
}
