<?php

namespace App\Modules\Health\Http\Controllers;

use App\Modules\Health\Domain\MeasurementService;
use App\Modules\Health\Http\Resources\MeasurementResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class SummaryController extends HealthController
{
    public function __invoke(Request $request, MeasurementService $measurements): JsonResponse
    {
        $summary = $measurements->summary($this->user($request));

        return response()->json(['data' => [
            ...$summary,
            'latest' => $summary['latest'] === null ? null : (new MeasurementResource($summary['latest']))->resolve($request),
            'latest_with_metrics' => $summary['latest_with_metrics'] === null ? null : (new MeasurementResource($summary['latest_with_metrics']))->resolve($request),
        ]]);
    }
}
