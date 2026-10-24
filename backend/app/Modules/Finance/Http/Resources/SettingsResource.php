<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Models\FinanceSetting;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin FinanceSetting
 */
final class SettingsResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var FinanceSetting $settings */
        $settings = $this->resource;
        $lastUsed = Transaction::query()->ownedBy($settings->user_id)
            ->where('kind', '!=', 'transfer')
            ->latest('created_at')
            ->value('account_id');

        return [
            'default_account_id' => $settings->default_account_id,
            'last_used_account_id' => is_string($lastUsed) ? $lastUsed : null,
            'budget_warning_threshold' => $settings->budget_warning_threshold,
            'period_min_days' => $settings->period_min_days,
            'period_mode' => $settings->period_mode->value,
            'remind_days_before' => $settings->remind_days_before,
        ];
    }
}
