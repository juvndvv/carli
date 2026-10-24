<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Http\Requests\StorePeriodRequest;
use App\Modules\Finance\Http\Resources\PeriodResource;
use App\Modules\Finance\Models\Period;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

final class PeriodController extends FinanceController
{
    public function __construct(private readonly PeriodService $periods) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return PeriodResource::collection($this->periods->all($this->user($request)));
    }

    public function store(StorePeriodRequest $request): JsonResponse
    {
        $period = $this->periods->openManual($request->financeUser(), SpanishCalendar::date((string) $request->validated('start_date')));

        return (new PeriodResource($period->refresh()))->response()->setStatusCode(201);
    }

    public function update(StorePeriodRequest $request, Period $period): PeriodResource
    {
        $this->authorizeOwner('update', $period);

        return new PeriodResource($this->periods->moveStart($period, SpanishCalendar::date((string) $request->validated('start_date')))->refresh());
    }
}
