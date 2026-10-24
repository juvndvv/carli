<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * @property string $id
 * @property string $user_id
 * @property string $account_id
 * @property TransactionKind $kind
 * @property int $amount_cents
 * @property CarbonImmutable $date
 * @property string|null $category_id
 * @property string|null $payee
 * @property string|null $description
 * @property string|null $notes
 * @property TransactionStatus $status
 * @property string|null $transfer_group_id
 * @property string|null $recurring_rule_id
 * @property CarbonImmutable|null $recurring_date
 * @property string|null $debt_id
 * @property CarbonImmutable|null $deleted_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Account $account
 * @property-read Category|null $category
 * @property-read Collection<int, Tag> $tags
 * @property-read Collection<int, TransactionSplit> $splits
 * @property-read Collection<int, SharedExpenseShare> $shares
 * @property-read Transaction|null $counterpart
 */
class Transaction extends Model
{
    use BelongsToUser, HasUuids, SoftDeletes;

    protected $table = 'finance.transactions';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'status' => 'cleared',
    ];

    protected function casts(): array
    {
        return [
            'kind' => TransactionKind::class,
            'status' => TransactionStatus::class,
            'amount_cents' => 'integer',
            'date' => 'immutable_date',
            'recurring_date' => 'immutable_date',
            'deleted_at' => 'immutable_datetime',
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
     * @return BelongsToMany<Tag, $this>
     */
    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(Tag::class, 'finance.transaction_tag')->withoutGlobalScopes()->orderBy('name');
    }

    /**
     * @return HasMany<TransactionSplit, $this>
     */
    public function splits(): HasMany
    {
        return $this->hasMany(TransactionSplit::class);
    }

    /**
     * @return HasMany<SharedExpenseShare, $this>
     */
    public function shares(): HasMany
    {
        return $this->hasMany(SharedExpenseShare::class);
    }

    /**
     * @return BelongsTo<RecurringRule, $this>
     */
    public function recurringRule(): BelongsTo
    {
        return $this->belongsTo(RecurringRule::class)->withoutGlobalScopes();
    }

    /**
     * @return BelongsTo<Debt, $this>
     */
    public function debt(): BelongsTo
    {
        return $this->belongsTo(Debt::class)->withoutGlobalScopes();
    }

    /**
     * @return HasMany<Transaction, $this>
     */
    public function transferLegs(): HasMany
    {
        return $this->hasMany(Transaction::class, 'transfer_group_id', 'transfer_group_id')->withoutGlobalScopes();
    }

    public function counterpart(): ?Transaction
    {
        if ($this->transfer_group_id === null) {
            return null;
        }

        return Transaction::query()
            ->withoutGlobalScopes()
            ->where('transfer_group_id', $this->transfer_group_id)
            ->whereKeyNot($this->id)
            ->first();
    }

    public function isTransfer(): bool
    {
        return $this->kind === TransactionKind::Transfer;
    }

    public function sharedCents(): int
    {
        return (int) $this->shares->sum('amount_cents');
    }

    public function ownAmountCents(): int
    {
        if ($this->kind !== TransactionKind::Expense) {
            return $this->amount_cents;
        }

        return $this->amount_cents + $this->sharedCents();
    }
}
