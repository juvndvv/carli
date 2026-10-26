<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * @property string $id
 * @property string $user_id
 * @property string $outgoing_transaction_id
 * @property string $incoming_transaction_id
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 */
class TransferExclusion extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.transfer_exclusions';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }
}
