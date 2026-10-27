<?php

namespace App\Modules\Habits\Http\Controllers;

use App\Modules\Habits\Domain\Services\BreakService;
use App\Modules\Habits\Http\Requests\BreakRequest;
use App\Modules\Habits\Http\Resources\BreakResource;
use App\Modules\Habits\Models\HabitBreak;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class BreakController extends HabitsController
{
    public function __construct(private readonly BreakService $breaks) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return BreakResource::collection(
            HabitBreak::query()->ownedBy($this->user($request))->orderByDesc('from_date')->get()
        );
    }

    public function store(BreakRequest $request): JsonResponse
    {
        /** @var array{from_date: string, to_date: string, habit_id?: string|null} $data */
        $data = $request->validated();

        return (new BreakResource($this->breaks->create($request->habitsUser(), $data)))->response()->setStatusCode(201);
    }

    public function update(BreakRequest $request, HabitBreak $break): BreakResource
    {
        $this->authorizeOwner('update', $break);
        /** @var array{from_date?: string, to_date?: string} $data */
        $data = $request->validated();
        $updated = $this->breaks->update($break, $data);

        if ($updated->to_date->lt($updated->from_date)) {
            abort(422, 'El descanso termina antes de empezar.');
        }

        return new BreakResource($updated);
    }

    public function end(HabitBreak $break): JsonResponse
    {
        $this->authorizeOwner('update', $break);
        $ended = $this->breaks->end($break);

        return response()->json(['data' => $ended === null ? null : (new BreakResource($ended))->resolve()]);
    }

    public function destroy(HabitBreak $break): Response
    {
        $this->authorizeOwner('delete', $break);
        $break->delete();

        return response()->noContent();
    }
}
