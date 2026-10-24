<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\TransferService;
use App\Modules\Finance\Http\Requests\StoreTransferRequest;
use App\Modules\Finance\Http\Resources\TransactionResource;
use Illuminate\Http\JsonResponse;

final class TransferController extends FinanceController
{
    public function store(StoreTransferRequest $request, TransferService $transfers): JsonResponse
    {
        /** @var array{from_account_id: string, to_account_id: string, amount_cents: int, date: string, description?: string|null, notes?: string|null, status?: string|null, tags?: list<string>|null} $data */
        $data = $request->validated();
        $legs = $transfers->create($request->financeUser(), $data);

        return response()->json(['data' => [
            'transfer_group_id' => $legs['from']->transfer_group_id,
            'from' => (new TransactionResource($legs['from']))->resolve($request),
            'to' => (new TransactionResource($legs['to']))->resolve($request),
        ]], 201);
    }
}
