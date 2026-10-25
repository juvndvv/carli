<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\PendingIndexRequest;
use App\Core\Pending\PendingItem;
use App\Core\Pending\PendingRegistry;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PendingController
{
    public function __construct(private readonly PendingRegistry $pending) {}

    public function summary(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->pending->summary($this->user($request))]);
    }

    public function index(PendingIndexRequest $request): JsonResponse
    {
        $page = $this->pending->page(
            $this->user($request),
            $request->filter('module'),
            $request->filter('type'),
            $request->filter('cursor'),
        );

        return response()->json([
            'data' => array_map(fn (PendingItem $item) => $item->toArray(), $page->items),
            'meta' => [
                'has_more' => $page->nextCursor !== null,
                'next_cursor' => $page->nextCursor,
            ],
        ]);
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
