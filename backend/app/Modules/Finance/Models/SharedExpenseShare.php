<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\ShareMode;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $transaction_id
 * @property string $contact_id
 * @property int $amount_cents
 * @property ShareMode $mode
 * @property int|null $basis_points
 * @property bool $include_self
 * @property CarbonImmutable|null $settled_at
 * @property bool $from_reimbursement
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Contact $contact
 * @property-read Transaction $transaction
 * @property-read Collection<int, ShareSettlement> $settlements
 */
class SharedExpenseShare extends Model
{
    use HasUuids;

    protected $table = 'finance.shared_expense_shares';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'amount_cents' => 'integer',
            'mode' => ShareMode::class,
            'basis_points' => 'integer',
            'include_self' => 'boolean',
            'from_reimbursement' => 'boolean',
            'settled_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Transaction, $this>
     */
    public function transaction(): BelongsTo
    {
        return $this->belongsTo(Transaction::class)->withoutGlobalScopes();
    }

    /**
     * @return BelongsTo<Contact, $this>
     */
    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class)->withoutGlobalScopes();
    }

    /**
     * @return HasMany<ShareSettlement, $this>
     */
    public function settlements(): HasMany
    {
        return $this->hasMany(ShareSettlement::class, 'share_id');
    }

    public function settledCents(): int
    {
        return (int) $this->settlements->sum('amount_cents');
    }

    public function pendingCents(): int
    {
        return max(0, $this->amount_cents - $this->settledCents());
    }
}
