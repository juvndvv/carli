<?php

namespace App\Modules\Notes\Http\Controllers;

use App\Modules\Notes\Http\Requests\SearchNotesRequest;
use App\Modules\Notes\Queries\NoteSearch;
use App\Modules\Notes\Queries\NoteSearchHit;
use Illuminate\Http\JsonResponse;

final class SearchController extends NotesController
{
    public function __invoke(SearchNotesRequest $request, NoteSearch $search): JsonResponse
    {
        $hits = $search->search($this->user($request), (string) $request->validated('q'), $request->integer('limit', 30));

        return response()->json(['data' => array_map(fn (NoteSearchHit $hit) => $hit->toArray(), $hits)]);
    }
}
