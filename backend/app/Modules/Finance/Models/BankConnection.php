<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\BankConnectionStatus;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string $provider
 * @property string $aspsp_name
 * @property string $aspsp_country
 * @property string|null $session_id
 * @property CarbonImmutable $valid_until
 * @property BankConnectionStatus $status
 * @property list<array{uid: string, identification_hash: string|null, name: string|null, iban: string|null, currency: string|null, type: string|null}>|null $accounts
 * @property int|null $expiry_notice_days
 * @property int $last_sync_transfers
 * @property CarbonImmutable|null $last_synced_at
 * @property string|null $last_error
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Collection<int, Account> $linkedAccounts
 */
class BankConnection extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.bank_connections';

    protected $guarded = ['id', 'user_id'];

    protected $hidden = ['session_id'];

    protected $attributes = [
        'provider' => 'enable_banking',
        'status' => 'active',
        'last_sync_transfers' => 0,
    ];

    protected function casts(): array
    {
        return [
            'session_id' => 'encrypted',
            'valid_until' => 'immutable_datetime',
            'status' => BankConnectionStatus::class,
            'accounts' => 'array',
            'expiry_notice_days' => 'integer',
            'last_sync_transfers' => 'integer',
            'last_synced_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return HasMany<Account, $this>
     */
    public function linkedAccounts(): HasMany
    {
        return $this->hasMany(Account::class)->withoutGlobalScopes();
    }

    /**
     * @param  Builder<self>  $query
     */
    public function scopeSyncable(Builder $query): void
    {
        $query->whereIn('status', [BankConnectionStatus::Active->value, BankConnectionStatus::Error->value]);
    }

    public function isExpired(): bool
    {
        return $this->status === BankConnectionStatus::Expired || $this->valid_until->isPast();
    }

    public function effectiveStatus(): BankConnectionStatus
    {
        if ($this->status->isSyncable() && $this->valid_until->isPast()) {
            return BankConnectionStatus::Expired;
        }

        return $this->status;
    }

    /**
     * @return array{uid: string, identification_hash: string|null, name: string|null, iban: string|null, currency: string|null, type: string|null}|null
     */
    public function bankAccount(string $uid): ?array
    {
        foreach ($this->accounts ?? [] as $account) {
            if ($account['uid'] === $uid) {
                return $account;
            }
        }

        return null;
    }
}
