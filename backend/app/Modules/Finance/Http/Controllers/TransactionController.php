<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Http\Requests\BulkUpdateTransactionsRequest;
use App\Modules\Finance\Http\Requests\StoreTransactionRequest;
use App\Modules\Finance\Http\Requests\TransactionIndexRequest;
use App\Modules\Finance\Http\Requests\UpdateTransactionRequest;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Queries\TransactionCsvExporter;
use App\Modules\Finance\Queries\TransactionCursor;
use App\Modules\Finance\Queries\TransactionFilter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class TransactionController extends FinanceController
{
    public function __construct(
        private readonly TransactionService $transactions,
        private readonly TransactionFilter $filter,
    ) {}

    public function index(TransactionIndexRequest $request): AnonymousResourceCollection
    {
        $user = $request->financeUser();
        $query = $this->filter->apply($user->id, $request->filters());
        $totals = $this->filter->totals($query);
        $perPage = (int) ($request->validated('per_page') ?? 50);
        $cursor = TransactionCursor::decode($request->validated('cursor'));

        if ($cursor !== null) {
            $query->whereRaw('(date, id) < (?::date, ?::uuid)', [$cursor['date'], $cursor['id']]);
        }

        $rows = $query->with(TransactionResource::RELATIONS)
            ->orderByDesc('date')
            ->orderByDesc('id')
            ->limit($perPage + 1)
            ->get();

        $hasMore = $rows->count() > $perPage;
        $page = $rows->take($perPage)->values();
        $last = $page->last();

        return TransactionResource::collection($page)->additional(['meta' => [
            'per_page' => $perPage,
            'has_more' => $hasMore,
            'next_cursor' => $hasMore && $last !== null ? TransactionCursor::encode($last) : null,
            'totals' => $totals,
        ]]);
    }

    public function store(StoreTransactionRequest $request): JsonResponse
    {
        $transaction = $this->transactions->create($request->financeUser(), $request->payload());

        return (new TransactionResource($transaction))
            ->additional(['meta' => ['periods_changed' => $this->transactions->periodsChanged]])
            ->response()
            ->setStatusCode(201);
    }

    public function show(Transaction $transaction): TransactionResource
    {
        $this->authorizeOwner('view', $transaction);

        return new TransactionResource($transaction);
    }

    public function update(UpdateTransactionRequest $request, Transaction $transaction): TransactionResource
    {
        $this->authorizeOwner('update', $transaction);
        $transaction = $this->transactions->update($transaction, $request->payload());

        return (new TransactionResource($transaction))
            ->additional(['meta' => ['periods_changed' => $this->transactions->periodsChanged]]);
    }

    public function destroy(Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner('delete', $transaction);
        $this->transactions->delete($transaction);

        return response()->json(['meta' => ['periods_changed' => $this->transactions->periodsChanged]]);
    }

    public function restore(Transaction $transaction): TransactionResource
    {
        $this->authorizeOwner('update', $transaction);
        $transaction = $this->transactions->restore($transaction);

        return (new TransactionResource($transaction))
            ->additional(['meta' => ['periods_changed' => $this->transactions->periodsChanged]]);
    }

    public function bulk(BulkUpdateTransactionsRequest $request): JsonResponse
    {
        $data = $request->validated();
        $updated = $this->transactions->bulkUpdate(
            $request->financeUser(),
            array_values(array_map('strval', $data['ids'])),
            array_diff_key($data, ['ids' => true]),
        );

        return response()->json(['data' => ['updated' => $updated]]);
    }

    public function export(TransactionIndexRequest $request, TransactionCsvExporter $exporter): StreamedResponse
    {
        $query = $this->filter->apply($request->financeUser()->id, $request->filters());

        return $exporter->download($query);
    }
}
