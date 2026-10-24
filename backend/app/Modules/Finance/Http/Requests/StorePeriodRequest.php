<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Support\SpanishCalendar;

final class StorePeriodRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'start_date' => ['required', 'date_format:Y-m-d', 'before_or_equal:'.SpanishCalendar::today()->addDays(31)->toDateString()],
        ];
    }
}
