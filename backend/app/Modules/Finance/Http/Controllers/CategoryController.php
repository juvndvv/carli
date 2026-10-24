<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\CategoryService;
use App\Modules\Finance\Http\Requests\DestroyCategoryRequest;
use App\Modules\Finance\Http\Requests\StoreCategoryRequest;
use App\Modules\Finance\Http\Requests\UpdateCategoryRequest;
use App\Modules\Finance\Http\Resources\CategoryResource;
use App\Modules\Finance\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class CategoryController extends FinanceController
{
    public function __construct(private readonly CategoryService $categories) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $this->user($request);
        $query = Category::query()->ownedBy($user)
            ->when($request->filled('kind'), fn ($builder) => $builder->where('kind', $request->string('kind')->toString()))
            ->when(! $request->boolean('include_archived'), fn ($builder) => $builder->whereNull('archived_at'))
            ->orderBy('kind')
            ->orderBy('sort_order')
            ->orderBy('name');

        if ($request->boolean('flat')) {
            return CategoryResource::collection($query->get());
        }

        $includeArchived = $request->boolean('include_archived');

        return CategoryResource::collection(
            $query->whereNull('parent_id')
                ->with(['children' => fn ($children) => $includeArchived ? $children : $children->whereNull('archived_at')])
                ->get()
        );
    }

    public function store(StoreCategoryRequest $request): JsonResponse
    {
        $category = $this->categories->create($request->financeUser(), $request->validated());

        return (new CategoryResource($category->load('children')))->response()->setStatusCode(201);
    }

    public function show(Category $category): CategoryResource
    {
        $this->authorizeOwner('view', $category);

        return new CategoryResource($category->load('children'));
    }

    public function update(UpdateCategoryRequest $request, Category $category): CategoryResource
    {
        $this->authorizeOwner('update', $category);

        return new CategoryResource($this->categories->update($category, $request->validated())->load('children'));
    }

    public function destroy(DestroyCategoryRequest $request, Category $category): Response
    {
        $this->authorizeOwner('delete', $category);
        $reassignTo = $request->validated('reassign_to');
        $this->categories->delete($category, is_string($reassignTo) ? $reassignTo : null);

        return response()->noContent();
    }
}
