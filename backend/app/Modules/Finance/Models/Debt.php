<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\DebtDirection;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string|null $contact_id
 * @property string $name
 * @property DebtDirection $direction
 * @property int $principal_cents
 * @property CarbonImmutable $start_date
 * @property CarbonImmutable|null $due_date
 * @property int|null $installment_cents
 * @property int|null $installments_count
 * @property string|null $recurring_rule_id
 * @property string|null $notes
 * @property CarbonImmutable|null $closed_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property int|null $payments_sum_cents
 * @property-read Contact|null $contact
 * @property-read RecurringRule|null $recurringRule
 */
class Debt extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.debts';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'direction' => DebtDirection::class,
            'principal_cents' => 'integer',
            'installment_cents' => 'integer',
            'installments_count' => 'integer',
            'start_date' => 'immutable_date',
            'due_date' => 'immutable_date',
            'closed_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Contact, $this>
     */
    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class)->withoutGlobalScopes();
    }

    /**
     * @return BelongsTo<RecurringRule, $this>
     */
    public function recurringRule(): BelongsTo
    {
        return $this->belongsTo(RecurringRule::class)->withoutGlobalScopes();
    }

    /**
     * @return HasMany<Transaction, $this>
     */
    public function payments(): HasMany
    {
        return $this->hasMany(Transaction::class)->withoutGlobalScopes();
    }

    public function paidCents(): int
    {
        $sum = array_key_exists('payments_sum_cents', $this->attributes)
            ? (int) $this->payments_sum_cents
            : (int) $this->payments()->whereNull('deleted_at')->where('status', TransactionStatus::Cleared->value)->sum('amount_cents');

        return $this->direction === DebtDirection::IOwe ? -$sum : $sum;
    }

    public function pendingCents(): int
    {
        return max(0, $this->principal_cents - $this->paidCents());
    }

    public function isClosed(): bool
    {
        return $this->closed_at !== null;
    }
}
