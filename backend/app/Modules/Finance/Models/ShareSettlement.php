<?php

namespace App\Modules\Finance\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Part of an income that pays back a contact's share of an expense.
 *
 * @property string $id
 * @property string $share_id
 * @property string $transaction_id
 * @property int $amount_cents
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read SharedExpenseShare $share
 * @property-read Transaction $transaction
 */
class ShareSettlement extends Model
{
    use HasUuids;

    protected $table = 'finance.share_settlements';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'amount_cents' => 'integer',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<SharedExpenseShare, $this>
     */
    public function share(): BelongsTo
    {
        return $this->belongsTo(SharedExpenseShare::class, 'share_id');
    }

    /**
     * @return BelongsTo<Transaction, $this>
     */
    public function transaction(): BelongsTo
    {
        return $this->belongsTo(Transaction::class)->withoutGlobalScopes();
    }
}
