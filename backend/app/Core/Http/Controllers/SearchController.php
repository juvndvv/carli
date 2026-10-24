<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\SearchRequest;
use App\Core\Search\GlobalSearch;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class SearchController
{
    public function __invoke(SearchRequest $request, GlobalSearch $search): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return response()->json([
            'data' => $search->search($user, trim((string) $request->validated('q')), $request->integer('limit', 5)),
        ]);
    }
}
