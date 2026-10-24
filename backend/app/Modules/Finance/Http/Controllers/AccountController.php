<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\AccountService;
use App\Modules\Finance\Http\Requests\ReconcileAccountRequest;
use App\Modules\Finance\Http\Requests\StoreAccountRequest;
use App\Modules\Finance\Http\Requests\UpdateAccountRequest;
use App\Modules\Finance\Http\Resources\AccountResource;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Queries\NetWorthQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class AccountController extends FinanceController
{
    public function __construct(private readonly AccountService $accounts) {}

    public function index(Request $request, NetWorthQuery $netWorth): AnonymousResourceCollection
    {
        $user = $this->user($request);
        $accounts = Account::query()->ownedBy($user)
            ->withBalance()
            ->when(! $request->boolean('include_archived'), fn ($query) => $query->whereNull('archived_at'))
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return AccountResource::collection($accounts)->additional([
            'meta' => ['net_worth_cents' => $netWorth->current($user->id)],
        ]);
    }

    public function store(StoreAccountRequest $request): JsonResponse
    {
        $account = $this->accounts->create($request->financeUser(), $request->validated());

        return (new AccountResource($account))->response()->setStatusCode(201);
    }

    public function show(Account $account): AccountResource
    {
        $this->authorizeOwner('view', $account);

        return new AccountResource($this->accounts->reload($account));
    }

    public function update(UpdateAccountRequest $request, Account $account): AccountResource
    {
        $this->authorizeOwner('update', $account);

        return new AccountResource($this->accounts->update($account, $request->validated()));
    }

    public function destroy(Account $account): Response
    {
        $this->authorizeOwner('delete', $account);
        $this->accounts->delete($account);

        return response()->noContent();
    }

    public function reconcile(ReconcileAccountRequest $request, Account $account): JsonResponse
    {
        $this->authorizeOwner('update', $account);
        $result = $this->accounts->reconcile($account, (int) $request->integer('actual_balance_cents'), $request->validated('date'));

        return response()->json(['data' => [
            'account' => (new AccountResource($this->accounts->reload($account)))->resolve($request),
            'adjustment' => $result['adjustment'] === null ? null : (new TransactionResource($result['adjustment']))->resolve($request),
            'difference_cents' => $result['difference_cents'],
            'balance_cents' => $result['balance_cents'],
        ]], $result['adjustment'] === null ? 200 : 201);
    }
}
