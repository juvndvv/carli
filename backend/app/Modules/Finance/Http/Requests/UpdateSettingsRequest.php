<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\PeriodMode;
use Illuminate\Validation\Rule;

final class UpdateSettingsRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'default_account_id' => ['sometimes', ...$this->ownedId('accounts')],
            'budget_warning_threshold' => ['sometimes', 'integer', 'between:1,100'],
            'period_min_days' => ['sometimes', 'integer', 'between:1,60'],
            'period_mode' => ['sometimes', Rule::enum(PeriodMode::class)],
            'remind_days_before' => ['sometimes', 'integer', 'between:0,30'],
            'savings_target_percent' => ['sometimes', 'integer', 'between:1,100'],
        ];
    }
}
