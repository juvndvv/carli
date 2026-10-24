<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Http\Requests\CategorySuggestRequest;
use App\Modules\Finance\Http\Requests\PayeeSuggestRequest;
use App\Modules\Finance\Queries\PayeeSuggestions;
use Illuminate\Http\JsonResponse;

final class PayeeController extends FinanceController
{
    public function suggest(PayeeSuggestRequest $request, PayeeSuggestions $suggestions): JsonResponse
    {
        return response()->json(['data' => $suggestions->suggest(
            $request->financeUser()->id,
            (string) $request->validated('q', ''),
            $request->validated('kind'),
            (int) ($request->validated('limit') ?? 8),
        )]);
    }

    public function suggestCategory(CategorySuggestRequest $request, PayeeSuggestions $suggestions): JsonResponse
    {
        return response()->json(['data' => $suggestions->suggestCategory(
            $request->financeUser()->id,
            $request->validated('payee'),
            $request->validated('description'),
            $request->validated('kind'),
        )]);
    }
}
