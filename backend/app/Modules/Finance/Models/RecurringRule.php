<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\RecurrenceFrequency;
use App\Modules\Finance\Domain\Enums\RecurringMode;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * @property string $id
 * @property string $user_id
 * @property string $account_id
 * @property string|null $category_id
 * @property TransactionKind $kind
 * @property int $amount_cents
 * @property string|null $payee
 * @property string|null $description
 * @property RecurrenceFrequency $frequency
 * @property int $interval
 * @property int|null $day_of_month
 * @property CarbonImmutable $start_date
 * @property CarbonImmutable|null $end_date
 * @property CarbonImmutable|null $next_occurrence
 * @property RecurringMode $mode
 * @property int $remind_days_before
 * @property bool $is_subscription
 * @property CarbonImmutable|null $cancelled_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Account $account
 * @property-read Category|null $category
 * @property-read Debt|null $debt
 */
class RecurringRule extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.recurring_rules';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'interval' => 1,
        'mode' => 'auto',
        'remind_days_before' => 2,
        'is_subscription' => false,
    ];

    protected function casts(): array
    {
        return [
            'kind' => TransactionKind::class,
            'frequency' => RecurrenceFrequency::class,
            'mode' => RecurringMode::class,
            'amount_cents' => 'integer',
            'interval' => 'integer',
            'day_of_month' => 'integer',
            'remind_days_before' => 'integer',
            'is_subscription' => 'boolean',
            'start_date' => 'immutable_date',
            'end_date' => 'immutable_date',
            'next_occurrence' => 'immutable_date',
            'cancelled_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Account, $this>
     */
    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class)->withoutGlobalScopes();
    }

    /**
     * @return BelongsTo<Category, $this>
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class)->withoutGlobalScopes();
    }

    /**
     * @return HasMany<Transaction, $this>
     */
    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class)->withoutGlobalScopes();
    }

    /**
     * @return HasOne<Debt, $this>
     */
    public function debt(): HasOne
    {
        return $this->hasOne(Debt::class)->withoutGlobalScopes();
    }

    public function isActive(): bool
    {
        return $this->cancelled_at === null && $this->next_occurrence !== null;
    }

    public function displayName(): string
    {
        return $this->payee ?? $this->description ?? 'Recurrente';
    }
}
