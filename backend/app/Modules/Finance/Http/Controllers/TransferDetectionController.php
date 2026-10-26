<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Enums\TransferSource;
use App\Modules\Finance\Domain\Services\TransferConversionService;
use App\Modules\Finance\Http\Requests\LinkTransferRequest;
use App\Modules\Finance\Http\Requests\TransferSuggestionRequest;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class TransferDetectionController extends FinanceController
{
    public function __construct(private readonly TransferConversionService $conversions) {}

    public function confirm(TransferSuggestionRequest $request): JsonResponse
    {
        $user = $request->financeUser();
        $outgoing = Transaction::query()->ownedBy($user)->findOrFail((string) $request->validated('outgoing_transaction_id'));
        $incoming = Transaction::query()->ownedBy($user)->findOrFail((string) $request->validated('incoming_transaction_id'));

        return $this->transfer($request, $this->conversions->convert($outgoing, $incoming, TransferSource::Confirmed));
    }

    public function dismiss(TransferSuggestionRequest $request): JsonResponse
    {
        $this->conversions->dismiss(
            $request->financeUser(),
            (string) $request->validated('outgoing_transaction_id'),
            (string) $request->validated('incoming_transaction_id'),
        );

        return response()->json(['data' => ['dismissed' => true]]);
    }

    public function link(LinkTransferRequest $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner('update', $transaction);

        return $this->transfer($request, $this->conversions->link($transaction, (string) $request->validated('account_id')));
    }

    public function undo(Request $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner('update', $transaction);
        $restored = $this->conversions->undo($transaction);

        return response()->json(['data' => array_map(
            fn (Transaction $each) => (new TransactionResource($each))->resolve($request),
            $restored,
        )]);
    }

    /**
     * @param  array{from: Transaction, to: Transaction}  $legs
     */
    private function transfer(Request $request, array $legs): JsonResponse
    {
        return response()->json(['data' => [
            'transfer_group_id' => $legs['from']->transfer_group_id,
            'from' => (new TransactionResource($legs['from']))->resolve($request),
            'to' => (new TransactionResource($legs['to']))->resolve($request),
        ]], 201);
    }
}
