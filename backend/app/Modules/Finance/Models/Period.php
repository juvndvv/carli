<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\PeriodOpenedBy;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property CarbonImmutable $start_date
 * @property CarbonImmutable|null $end_date
 * @property CarbonImmutable|null $expected_end_date
 * @property PeriodOpenedBy $opened_by
 * @property string|null $opening_transaction_id
 * @property CarbonImmutable|null $payroll_overdue_notified_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class Period extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.periods';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'start_date' => 'immutable_date',
            'end_date' => 'immutable_date',
            'expected_end_date' => 'immutable_date',
            'opened_by' => PeriodOpenedBy::class,
            'payroll_overdue_notified_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return HasMany<Budget, $this>
     */
    public function budgets(): HasMany
    {
        return $this->hasMany(Budget::class)->withoutGlobalScopes();
    }

    public function isOpen(): bool
    {
        return $this->end_date === null;
    }

    public function effectiveEndDate(): CarbonImmutable
    {
        return $this->end_date ?? $this->expected_end_date ?? $this->start_date->addMonthNoOverflow()->subDay();
    }

    public function contains(CarbonImmutable $date): bool
    {
        return $date->greaterThanOrEqualTo($this->start_date)
            && ($this->end_date === null || $date->lessThanOrEqualTo($this->end_date));
    }
}
