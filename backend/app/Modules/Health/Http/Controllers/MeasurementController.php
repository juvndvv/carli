<?php

namespace App\Modules\Health\Http\Controllers;

use App\Modules\Health\Domain\MeasurementService;
use App\Modules\Health\Http\Requests\MeasurementsRequest;
use App\Modules\Health\Http\Requests\StoreMeasurementRequest;
use App\Modules\Health\Http\Requests\SyncMeasurementsRequest;
use App\Modules\Health\Http\Resources\MeasurementResource;
use App\Modules\Health\Models\Measurement;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

final class MeasurementController extends HealthController
{
    public function __construct(private readonly MeasurementService $measurements) {}

    public function index(MeasurementsRequest $request): AnonymousResourceCollection
    {
        $query = Measurement::query()->ownedBy($this->user($request))->orderByDesc('measured_at');

        if ($request->filled('from')) {
            $query->where('measured_at', '>=', CarbonImmutable::parse((string) $request->validated('from'), 'Europe/Madrid')->startOfDay());
        }

        if ($request->filled('to')) {
            $query->where('measured_at', '<', CarbonImmutable::parse((string) $request->validated('to'), 'Europe/Madrid')->startOfDay()->addDay());
        }

        return MeasurementResource::collection($query->limit(2000)->get());
    }

    public function show(Measurement $measurement): MeasurementResource
    {
        Gate::authorize('view', $measurement);

        return new MeasurementResource($measurement);
    }

    public function store(StoreMeasurementRequest $request): JsonResponse
    {
        $measurement = $this->measurements->store($this->user($request), $request->validated());

        return (new MeasurementResource($measurement))->response()->setStatusCode(201);
    }

    public function sync(SyncMeasurementsRequest $request): JsonResponse
    {
        /** @var list<array<string, mixed>> $readings */
        $readings = $request->validated('readings');

        return response()->json(['data' => $this->measurements->sync($this->user($request), $readings)]);
    }

    public function destroy(Measurement $measurement): Response
    {
        Gate::authorize('delete', $measurement);
        $measurement->delete();

        return response()->noContent();
    }
}
