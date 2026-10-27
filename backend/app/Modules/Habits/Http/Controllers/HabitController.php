<?php

namespace App\Modules\Habits\Http\Controllers;

use App\Modules\Habits\Domain\Services\HabitReport;
use App\Modules\Habits\Domain\Services\HabitService;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Http\Requests\CalendarRequest;
use App\Modules\Habits\Http\Requests\ReorderHabitsRequest;
use App\Modules\Habits\Http\Requests\StoreHabitRequest;
use App\Modules\Habits\Models\Habit;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

final class HabitController extends HabitsController
{
    public function __construct(
        private readonly HabitService $habits,
        private readonly HabitReport $report,
    ) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->report->list($this->user($request))]);
    }

    public function store(StoreHabitRequest $request): JsonResponse
    {
        $habit = $this->habits->create($request->habitsUser(), $request->validated());

        return response()->json(['data' => $this->report->detail($habit)], 201);
    }

    public function show(Habit $habit): JsonResponse
    {
        $this->authorizeOwner('view', $habit);

        return response()->json(['data' => $this->report->detail($habit)]);
    }

    public function update(StoreHabitRequest $request, Habit $habit): JsonResponse
    {
        $this->authorizeOwner('update', $habit);

        return response()->json(['data' => $this->report->detail($this->habits->update($habit, $request->validated()))]);
    }

    public function destroy(Habit $habit): Response
    {
        $this->authorizeOwner('delete', $habit);
        $this->habits->delete($habit);

        return response()->noContent();
    }

    public function pause(Habit $habit): JsonResponse
    {
        return $this->transition($habit, $this->habits->pause(...));
    }

    public function resume(Habit $habit): JsonResponse
    {
        return $this->transition($habit, $this->habits->resume(...));
    }

    public function archive(Habit $habit): JsonResponse
    {
        return $this->transition($habit, $this->habits->archive(...));
    }

    public function unarchive(Habit $habit): JsonResponse
    {
        return $this->transition($habit, $this->habits->unarchive(...));
    }

    public function reorder(ReorderHabitsRequest $request): Response
    {
        /** @var list<string> $ids */
        $ids = $request->validated('ids');
        $this->habits->reorder($request->habitsUser(), $ids);

        return response()->noContent();
    }

    public function calendar(CalendarRequest $request, Habit $habit): JsonResponse
    {
        $this->authorizeOwner('view', $habit);
        $month = $request->validated('month');
        $date = is_string($month)
            ? CarbonImmutable::createFromFormat('!Y-m-d', $month.'-01', HabitCalendar::TIMEZONE) ?: HabitCalendar::today()
            : HabitCalendar::today();

        return response()->json(['data' => $this->report->calendar($habit, $date->startOfMonth())]);
    }

    /**
     * @param  callable(Habit): Habit  $change
     */
    private function transition(Habit $habit, callable $change): JsonResponse
    {
        $this->authorizeOwner('update', $habit);
        $habit = $change($habit);
        $habit->unsetRelation('breaks');

        return response()->json(['data' => $this->report->detail($habit)]);
    }
}
