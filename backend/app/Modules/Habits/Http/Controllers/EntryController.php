<?php

namespace App\Modules\Habits\Http\Controllers;

use App\Modules\Habits\Domain\Services\EntryService;
use App\Modules\Habits\Domain\Services\HabitReport;
use App\Modules\Habits\Http\Requests\EntryRequest;
use App\Modules\Habits\Models\Habit;
use Illuminate\Http\JsonResponse;

final class EntryController extends HabitsController
{
    public function __construct(
        private readonly EntryService $entries,
        private readonly HabitReport $report,
    ) {}

    public function update(EntryRequest $request, Habit $habit): JsonResponse
    {
        $this->authorizeOwner('update', $habit);
        $note = $request->validated('note');
        $entry = $this->entries->set($habit, $request->day(), (float) $request->validated('value'), is_string($note) ? $note : null);

        return $this->respond($habit, $entry === null ? null : ['date' => $entry->date->toDateString(), 'value' => $entry->value, 'note' => $entry->note, 'source' => $entry->source->value]);
    }

    public function destroy(EntryRequest $request, Habit $habit): JsonResponse
    {
        $this->authorizeOwner('update', $habit);
        $this->entries->delete($habit, $request->day());

        return $this->respond($habit, null);
    }

    /**
     * @param  array<string, mixed>|null  $entry
     */
    private function respond(Habit $habit, ?array $entry): JsonResponse
    {
        return response()->json(['data' => [
            'entry' => $entry,
            'today' => $this->report->todayItem($habit),
        ]]);
    }
}
