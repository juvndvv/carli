<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\ShareMode;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $transaction_id
 * @property string $contact_id
 * @property int $amount_cents
 * @property ShareMode $mode
 * @property int|null $basis_points
 * @property bool $include_self
 * @property CarbonImmutable|null $settled_at
 * @property string|null $settlement_transaction_id
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Contact $contact
 * @property-read Transaction $transaction
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
}
