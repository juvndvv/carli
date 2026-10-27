<?php

namespace App\Modules\Habits\Http\Controllers;

use App\Modules\Habits\Domain\Services\HabitReport;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Http\Requests\ProgressRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class AgendaController extends HabitsController
{
    public function __construct(private readonly HabitReport $report) {}

    public function today(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->report->today($this->user($request))]);
    }

    public function progress(ProgressRequest $request): JsonResponse
    {
        $date = $request->validated('date');

        return response()->json(['data' => $this->report->progress(
            $request->habitsUser(),
            (string) $request->validated('range', 'week'),
            is_string($date) ? HabitCalendar::date($date) : HabitCalendar::today(),
        )]);
    }
}
