<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Enums\DebtDirection;
use App\Modules\Finance\Domain\Services\DebtService;
use App\Modules\Finance\Http\Requests\StoreDebtPaymentRequest;
use App\Modules\Finance\Http\Requests\StoreDebtRequest;
use App\Modules\Finance\Http\Resources\DebtResource;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class DebtController extends FinanceController
{
    public function __construct(private readonly DebtService $debts) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $debts = Debt::query()->ownedBy($this->user($request))
            ->with(['contact', 'recurringRule'])
            ->when(! $request->boolean('include_closed'), fn ($query) => $query->whereNull('closed_at'))
            ->orderBy('start_date')
            ->get();

        $open = $debts->filter(fn (Debt $debt) => ! $debt->isClosed());

        return DebtResource::collection($debts)->additional(['meta' => [
            'owed_to_me_cents' => $open->filter(fn (Debt $debt) => $debt->direction === DebtDirection::OwedToMe)->sum(fn (Debt $debt) => $debt->pendingCents()),
            'i_owe_cents' => $open->filter(fn (Debt $debt) => $debt->direction === DebtDirection::IOwe)->sum(fn (Debt $debt) => $debt->pendingCents()),
        ]]);
    }

    public function store(StoreDebtRequest $request): JsonResponse
    {
        return (new DebtResource($this->debts->create($request->financeUser(), $request->validated())))->response()->setStatusCode(201);
    }

    public function show(Debt $debt): DebtResource
    {
        $this->authorizeOwner('view', $debt);

        return new DebtResource($debt);
    }

    public function update(StoreDebtRequest $request, Debt $debt): DebtResource
    {
        $this->authorizeOwner('update', $debt);

        return new DebtResource($this->debts->update($debt, $request->validated()));
    }

    public function destroy(Debt $debt): Response
    {
        $this->authorizeOwner('delete', $debt);
        $this->debts->delete($debt);

        return response()->noContent();
    }

    public function payments(Debt $debt): AnonymousResourceCollection
    {
        $this->authorizeOwner('view', $debt);

        return TransactionResource::collection(
            Transaction::query()->ownedBy($debt->user_id)->where('debt_id', $debt->id)
                ->with(TransactionResource::RELATIONS)
                ->orderByDesc('date')
                ->get()
        );
    }

    public function storePayment(StoreDebtPaymentRequest $request, Debt $debt): JsonResponse
    {
        $this->authorizeOwner('update', $debt);

        /** @var array{account_id: string, amount_cents: int, date?: string|null, category_id?: string|null, description?: string|null, notes?: string|null} $data */
        $data = $request->validated();
        $payment = $this->debts->addPayment($debt, $data);

        return response()->json([
            'data' => (new TransactionResource($payment))->resolve($request),
            'meta' => ['debt' => (new DebtResource($debt->refresh()))->resolve($request)],
        ], 201);
    }
}
