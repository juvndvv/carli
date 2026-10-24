<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\TagService;
use App\Modules\Finance\Http\Requests\MergeTagRequest;
use App\Modules\Finance\Http\Requests\StoreTagRequest;
use App\Modules\Finance\Http\Resources\TagResource;
use App\Modules\Finance\Models\Tag;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class TagController extends FinanceController
{
    public function __construct(private readonly TagService $tags) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return TagResource::collection(
            Tag::query()->ownedBy($this->user($request))->withCount('transactions')->orderBy('name')->get()
        );
    }

    public function store(StoreTagRequest $request): JsonResponse
    {
        $tag = $this->tags->create($request->financeUser(), (string) $request->validated('name'), $request->validated('color'));

        return (new TagResource($tag))->response()->setStatusCode(201);
    }

    public function show(Tag $tag): TagResource
    {
        $this->authorizeOwner('view', $tag);

        return new TagResource($tag);
    }

    public function update(StoreTagRequest $request, Tag $tag): TagResource
    {
        $this->authorizeOwner('update', $tag);

        /** @var array{name?: string, color?: string|null} $data */
        $data = $request->validated();

        return new TagResource($this->tags->update($tag, $data));
    }

    public function merge(MergeTagRequest $request, Tag $tag): TagResource
    {
        $this->authorizeOwner('update', $tag);
        $target = Tag::query()->ownedBy($request->financeUser())->whereKey((string) $request->validated('into_tag_id'))->firstOrFail();

        return new TagResource($this->tags->merge($tag, $target));
    }

    public function destroy(Tag $tag): Response
    {
        $this->authorizeOwner('delete', $tag);
        $this->tags->delete($tag);

        return response()->noContent();
    }
}
