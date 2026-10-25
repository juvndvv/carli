<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\CategoryRuleService;
use App\Modules\Finance\Domain\Support\MerchantText;
use App\Modules\Finance\Http\Requests\CategorizeSimilarRequest;
use App\Modules\Finance\Http\Requests\SimilarTransactionsRequest;
use App\Modules\Finance\Http\Resources\CategoryRuleResource;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Http\JsonResponse;

final class SimilarTransactionsController extends FinanceController
{
    public function __construct(private readonly CategoryRuleService $rules) {}

    public function count(SimilarTransactionsRequest $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner('view', $transaction);
        $pattern = $request->validated('pattern');
        $similar = $this->rules->similar($transaction, is_string($pattern) ? $pattern : null);

        return response()->json(['data' => [
            'count' => $similar->count(),
            'pattern' => is_string($pattern) ? MerchantText::normalize($pattern) : MerchantText::of($transaction->payee, $transaction->description),
            'transaction_ids' => $similar->pluck('id')->values()->all(),
        ]]);
    }

    public function categorize(CategorizeSimilarRequest $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner('update', $transaction);
        $pattern = $request->validated('pattern');

        $result = $this->rules->applyToSimilar(
            $transaction,
            (string) $request->validated('category_id'),
            $request->boolean('remember'),
            is_string($pattern) ? $pattern : null,
        );

        return response()->json(['data' => [
            'updated' => $result['updated'],
            'transaction' => (new TransactionResource($transaction->refresh()))->resolve($request),
            'rule' => $result['rule'] === null ? null : (new CategoryRuleResource($result['rule']))->resolve($request),
        ]]);
    }
}
