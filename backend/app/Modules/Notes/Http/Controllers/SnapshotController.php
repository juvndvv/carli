<?php

namespace App\Modules\Notes\Http\Controllers;

use App\Modules\Notes\Queries\SnapshotQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class SnapshotController extends NotesController
{
    public function __invoke(Request $request, SnapshotQuery $snapshot): JsonResponse
    {
        return response()->json(['data' => $snapshot->build($this->user($request), $request)]);
    }
}
