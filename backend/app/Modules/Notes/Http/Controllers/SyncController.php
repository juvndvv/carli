<?php

namespace App\Modules\Notes\Http\Controllers;

use App\Modules\Notes\Domain\Services\SyncService;
use App\Modules\Notes\Domain\Sync\OperationResult;
use App\Modules\Notes\Http\Requests\SyncRequest;
use App\Modules\Notes\Queries\SnapshotQuery;
use Illuminate\Http\JsonResponse;

final class SyncController extends NotesController
{
    public function __invoke(SyncRequest $request, SyncService $sync, SnapshotQuery $snapshot): JsonResponse
    {
        $user = $this->user($request);
        $results = $sync->apply($user, $request->operations());

        return response()->json([
            'results' => array_map(fn (OperationResult $result) => $result->toArray(), $results),
            'data' => $snapshot->build($user, $request),
        ]);
    }
}
