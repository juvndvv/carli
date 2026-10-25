<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\AccountType;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;

/**
 * @property string $id
 * @property string $user_id
 * @property string $name
 * @property AccountType $type
 * @property int $initial_balance_cents
 * @property CarbonImmutable|null $initial_balance_date
 * @property int|null $credit_limit_cents
 * @property int|null $statement_day
 * @property int|null $payment_day
 * @property string|null $color
 * @property string|null $icon
 * @property bool $include_in_net_worth
 * @property int $sort_order
 * @property CarbonImmutable|null $archived_at
 * @property string|null $bank_connection_id
 * @property string|null $external_account_uid
 * @property string|null $external_account_hash
 * @property CarbonImmutable|null $sync_from_date
 * @property int|null $bank_balance_cents
 * @property CarbonImmutable|null $bank_balance_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property int|null $transactions_sum_cents
 * @property int|null $pending_sum_cents
 * @property-read BankConnection|null $bankConnection
 */
class Account extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.accounts';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'initial_balance_cents' => 0,
        'include_in_net_worth' => true,
        'sort_order' => 0,
    ];

    protected function casts(): array
    {
        return [
            'type' => AccountType::class,
            'initial_balance_cents' => 'integer',
            'initial_balance_date' => 'immutable_date',
            'credit_limit_cents' => 'integer',
            'statement_day' => 'integer',
            'payment_day' => 'integer',
            'include_in_net_worth' => 'boolean',
            'sort_order' => 'integer',
            'archived_at' => 'immutable_datetime',
            'sync_from_date' => 'immutable_date',
            'bank_balance_cents' => 'integer',
            'bank_balance_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
            'transactions_sum_cents' => 'integer',
            'pending_sum_cents' => 'integer',
        ];
    }

    /**
     * @return BelongsTo<BankConnection, $this>
     */
    public function bankConnection(): BelongsTo
    {
        return $this->belongsTo(BankConnection::class)->withoutGlobalScopes();
    }

    public function isBankLinked(): bool
    {
        return $this->bank_connection_id !== null && $this->external_account_uid !== null;
    }

    /**
     * @return HasMany<Transaction, $this>
     */
    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    /**
     * @param  Builder<self>  $query
     */
    public function scopeWithBalance(Builder $query): void
    {
        if ($query->getQuery()->columns === null) {
            $query->select($query->qualifyColumn('*'));
        }

        $query->addSelect([
            'transactions_sum_cents' => Transaction::query()
                ->withoutGlobalScopes()
                ->selectRaw('coalesce(sum(amount_cents), 0)')
                ->whereColumn('finance.transactions.account_id', 'finance.accounts.id')
                ->whereNull('finance.transactions.deleted_at'),
            'pending_sum_cents' => Transaction::query()
                ->withoutGlobalScopes()
                ->selectRaw('coalesce(sum(amount_cents), 0)')
                ->whereColumn('finance.transactions.account_id', 'finance.accounts.id')
                ->whereNull('finance.transactions.deleted_at')
                ->where('finance.transactions.status', 'pending'),
        ]);
    }

    /**
     * @param  Builder<self>  $query
     */
    public function scopeActive(Builder $query): void
    {
        $query->whereNull('archived_at');
    }

    public function balanceCents(): int
    {
        if (! array_key_exists('transactions_sum_cents', $this->attributes)) {
            $sum = (int) DB::table('finance.transactions')
                ->where('account_id', $this->id)
                ->whereNull('deleted_at')
                ->sum('amount_cents');

            return $this->initial_balance_cents + $sum;
        }

        return $this->initial_balance_cents + (int) $this->transactions_sum_cents;
    }

    public function clearedBalanceCents(): int
    {
        return $this->balanceCents() - $this->pendingCents();
    }

    public function pendingCents(): int
    {
        if (! array_key_exists('pending_sum_cents', $this->attributes)) {
            return (int) DB::table('finance.transactions')
                ->where('account_id', $this->id)
                ->whereNull('deleted_at')
                ->where('status', 'pending')
                ->sum('amount_cents');
        }

        return (int) $this->pending_sum_cents;
    }

    public function isArchived(): bool
    {
        return $this->archived_at !== null;
    }
}
