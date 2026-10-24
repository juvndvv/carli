<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\GoalService;
use App\Modules\Finance\Http\Requests\StoreGoalContributionRequest;
use App\Modules\Finance\Http\Requests\StoreGoalRequest;
use App\Modules\Finance\Http\Resources\GoalContributionResource;
use App\Modules\Finance\Http\Resources\GoalResource;
use App\Modules\Finance\Models\GoalContribution;
use App\Modules\Finance\Models\SavingsGoal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class GoalController extends FinanceController
{
    public function __construct(private readonly GoalService $goals) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return GoalResource::collection(
            SavingsGoal::query()->ownedBy($this->user($request))->with('account')->orderByRaw('achieved_at IS NOT NULL')->orderBy('target_date')->orderBy('name')->get()
        );
    }

    public function store(StoreGoalRequest $request): JsonResponse
    {
        return (new GoalResource($this->goals->create($request->financeUser(), $request->validated())))->response()->setStatusCode(201);
    }

    public function show(SavingsGoal $goal): GoalResource
    {
        $this->authorizeOwner('view', $goal);

        return new GoalResource($goal);
    }

    public function update(StoreGoalRequest $request, SavingsGoal $goal): GoalResource
    {
        $this->authorizeOwner('update', $goal);

        return new GoalResource($this->goals->update($goal, $request->validated()));
    }

    public function destroy(SavingsGoal $goal): Response
    {
        $this->authorizeOwner('delete', $goal);
        $goal->delete();

        return response()->noContent();
    }

    public function contributions(SavingsGoal $goal): AnonymousResourceCollection
    {
        $this->authorizeOwner('view', $goal);

        return GoalContributionResource::collection($goal->contributions()->get());
    }

    public function storeContribution(StoreGoalContributionRequest $request, SavingsGoal $goal): JsonResponse
    {
        $this->authorizeOwner('update', $goal);

        /** @var array{amount_cents: int, date?: string|null, note?: string|null, transaction_id?: string|null} $data */
        $data = $request->validated();
        $contribution = $this->goals->contribute($goal, $data);

        return response()->json([
            'data' => (new GoalContributionResource($contribution))->resolve($request),
            'meta' => ['goal' => (new GoalResource($goal->refresh()))->resolve($request)],
        ], 201);
    }

    public function destroyContribution(SavingsGoal $goal, GoalContribution $contribution): Response
    {
        $this->authorizeOwner('update', $goal);
        abort_unless($contribution->goal_id === $goal->id, 404);
        $this->goals->removeContribution($contribution);

        return response()->noContent();
    }
}
