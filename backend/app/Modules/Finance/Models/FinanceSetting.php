<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\PeriodMode;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * @property string $id
 * @property string $user_id
 * @property string|null $default_account_id
 * @property int $budget_warning_threshold
 * @property int $period_min_days
 * @property PeriodMode $period_mode
 * @property int $remind_days_before
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class FinanceSetting extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.settings';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'budget_warning_threshold' => 80,
        'period_min_days' => 20,
        'period_mode' => 'payroll',
        'remind_days_before' => 2,
    ];

    protected function casts(): array
    {
        return [
            'budget_warning_threshold' => 'integer',
            'period_min_days' => 'integer',
            'period_mode' => PeriodMode::class,
            'remind_days_before' => 'integer',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }
}
