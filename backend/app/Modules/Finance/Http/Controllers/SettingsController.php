<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\FinanceSettingsService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Http\Requests\UpdateSettingsRequest;
use App\Modules\Finance\Http\Resources\SettingsResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class SettingsController extends FinanceController
{
    public function __construct(
        private readonly FinanceSettingsService $settings,
        private readonly PeriodService $periods,
    ) {}

    public function show(Request $request): JsonResponse
    {
        return (new SettingsResource($this->settings->for($this->user($request))))->response()->setStatusCode(200);
    }

    public function update(UpdateSettingsRequest $request): JsonResponse
    {
        $user = $request->financeUser();
        $rebuilt = false;

        DB::transaction(function () use ($user, $request, &$rebuilt): void {
            $settings = $this->settings->lockFor($user);
            $settings->fill($request->validated());
            $periodRulesChanged = $settings->isDirty(['period_mode', 'period_min_days']);
            $settings->save();

            if ($periodRulesChanged) {
                $rebuilt = $this->periods->rebuild($user);
            }
        });

        return (new SettingsResource($this->settings->for($user)))
            ->additional(['meta' => ['periods_changed' => $rebuilt]])
            ->response()
            ->setStatusCode(200);
    }
}
