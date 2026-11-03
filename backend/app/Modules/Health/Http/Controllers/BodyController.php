<?php

namespace App\Modules\Health\Http\Controllers;

use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Domain\BodyService;
use App\Modules\Health\Http\Requests\BodyOverviewRequest;
use App\Modules\Health\Http\Requests\BodySiteRequest;
use App\Modules\Health\Http\Requests\RecordBodyRequest;
use App\Modules\Health\Http\Requests\ReorderBodySitesRequest;
use App\Modules\Health\Http\Resources\BodyMeasurementResource;
use App\Modules\Health\Http\Resources\BodySiteResource;
use App\Modules\Health\Models\BodyMeasurement;
use App\Modules\Health\Models\BodySite;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

/**
 * Medidas del cuerpo: sites, sessions with the tape and how each site has changed.
 */
final class BodyController extends HealthController
{
    public function __construct(private readonly BodyService $body) {}

    /** The body viewer: every active site with its latest value and the change since the comparison point. */
    public function overview(BodyOverviewRequest $request): JsonResponse
    {
        $compare = $request->validated('compare');
        $overview = $this->body->overview($this->user($request), is_string($compare) ? $compare : 'first');

        return response()->json(['data' => [
            ...$overview,
            'sites' => array_map(fn (array $row): array => [
                ...(new BodySiteResource($row['site']))->resolve($request),
                'latest' => $row['latest'] === null ? null : (new BodyMeasurementResource($row['latest']))->resolve($request),
                'baseline' => $row['baseline'] === null ? null : (new BodyMeasurementResource($row['baseline']))->resolve($request),
                'change_cm' => $row['change_cm'],
                'count' => $row['count'],
            ], $overview['sites']),
        ]]);
    }

    public function sites(BodyOverviewRequest $request): AnonymousResourceCollection
    {
        return BodySiteResource::collection($this->body->sites($this->user($request), $request->boolean('archived')));
    }

    public function storeSite(BodySiteRequest $request): JsonResponse
    {
        /** @var array{name: string, zone: string, side?: string|null} $data */
        $data = $request->validated();
        $site = $this->body->create($this->user($request), $data);

        return (new BodySiteResource($site))->response()->setStatusCode(201);
    }

    public function updateSite(BodySiteRequest $request, BodySite $site): BodySiteResource
    {
        Gate::authorize('update', $site);

        return new BodySiteResource($this->body->update($site, $request->validated()));
    }

    public function reorder(ReorderBodySitesRequest $request): Response
    {
        /** @var list<string> $ids */
        $ids = $request->validated('ids');
        $this->body->reorder($this->user($request), $ids);

        return response()->noContent();
    }

    public function destroySite(BodySite $site): Response
    {
        Gate::authorize('delete', $site);
        $site->delete();

        return response()->noContent();
    }

    /** One site's history, oldest first, for its chart and list. */
    public function history(BodyOverviewRequest $request, BodySite $site): AnonymousResourceCollection
    {
        Gate::authorize('view', $site);
        $from = $request->validated('from');

        $query = $site->measurements()->orderBy('measured_at');
        if (is_string($from)) {
            $query->where('measured_at', '>=', HabitCalendar::date($from));
        }

        return BodyMeasurementResource::collection($query->limit(2000)->get());
    }

    public function record(RecordBodyRequest $request): JsonResponse
    {
        /** @var list<array{site_id: string, value_cm: float|int|string}> $values */
        $values = $request->validated('values');
        $at = $request->validated('measured_at');
        $saved = $this->body->record($this->user($request), $values, is_string($at) ? $at : null);

        return BodyMeasurementResource::collection($saved)->response()->setStatusCode(201);
    }

    public function destroyMeasurement(BodyMeasurement $bodyMeasurement): Response
    {
        Gate::authorize('delete', $bodyMeasurement);
        $bodyMeasurement->delete();

        return response()->noContent();
    }
}
