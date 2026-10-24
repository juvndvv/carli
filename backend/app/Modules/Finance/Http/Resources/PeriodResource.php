<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Domain\Support\PeriodPresenter;
use App\Modules\Finance\Models\Period;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Period
 */
final class PeriodResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Period $period */
        $period = $this->resource;

        return self::present($period);
    }

    /**
     * @return array<string, mixed>
     */
    public static function present(Period $period): array
    {
        return [
            'id' => $period->id,
            'start_date' => $period->start_date->toDateString(),
            'end_date' => $period->end_date?->toDateString(),
            'expected_end_date' => $period->expected_end_date?->toDateString(),
            'effective_end_date' => $period->effectiveEndDate()->toDateString(),
            'is_current' => $period->isOpen(),
            'opened_by' => $period->opened_by->value,
            'opening_transaction_id' => $period->opening_transaction_id,
            'name' => PeriodPresenter::name($period),
            'short_name' => PeriodPresenter::shortName($period),
            'range_label' => PeriodPresenter::rangeLabel($period),
            'label' => PeriodPresenter::label($period),
            'days_total' => PeriodPresenter::totalDays($period),
            'days_elapsed' => PeriodPresenter::elapsedDays($period),
            'days_remaining' => PeriodPresenter::remainingDays($period),
        ];
    }
}
