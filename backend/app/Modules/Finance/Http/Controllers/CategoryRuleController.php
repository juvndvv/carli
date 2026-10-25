<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\CategoryRuleService;
use App\Modules\Finance\Http\Requests\StoreCategoryRuleRequest;
use App\Modules\Finance\Http\Resources\CategoryRuleResource;
use App\Modules\Finance\Models\CategoryRule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class CategoryRuleController extends FinanceController
{
    public function __construct(private readonly CategoryRuleService $rules) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $rules = CategoryRule::query()->ownedBy($this->user($request))
            ->with('category.parent')
            ->orderBy('pattern')
            ->get();

        return CategoryRuleResource::collection($rules);
    }

    public function store(StoreCategoryRuleRequest $request): JsonResponse
    {
        /** @var array{pattern: string, category_id: string} $data */
        $data = $request->validated();

        return (new CategoryRuleResource($this->rules->create($request->financeUser(), $data)))->response()->setStatusCode(201);
    }

    public function show(CategoryRule $categoryRule): CategoryRuleResource
    {
        $this->authorizeOwner('view', $categoryRule);

        return new CategoryRuleResource($categoryRule);
    }

    public function update(StoreCategoryRuleRequest $request, CategoryRule $categoryRule): CategoryRuleResource
    {
        $this->authorizeOwner('update', $categoryRule);

        /** @var array{pattern?: string, category_id?: string} $data */
        $data = $request->validated();

        return new CategoryRuleResource($this->rules->update($categoryRule, $data));
    }

    public function destroy(CategoryRule $categoryRule): Response
    {
        $this->authorizeOwner('delete', $categoryRule);
        $categoryRule->delete();

        return response()->noContent();
    }
}
