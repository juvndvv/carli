<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin BankConnection
 */
final class BankConnectionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var BankConnection $connection */
        $connection = $this->resource;
        $connection->loadMissing('linkedAccounts');
        $validUntil = SpanishCalendar::date($connection->valid_until->setTimezone(SpanishCalendar::TIMEZONE));

        return [
            'id' => $connection->id,
            'provider' => $connection->provider,
            'aspsp_name' => $connection->aspsp_name,
            'aspsp_country' => $connection->aspsp_country,
            'status' => $connection->effectiveStatus()->value,
            'valid_until' => $connection->valid_until->toIso8601String(),
            'expires_in_days' => max(0, (int) SpanishCalendar::today()->diffInDays($validUntil, false)),
            'last_synced_at' => $connection->last_synced_at?->toIso8601String(),
            'last_error' => $connection->last_error,
            'last_sync_transfers' => $connection->last_sync_transfers,
            'bank_accounts_count' => count($connection->accounts ?? []),
            'linked_accounts' => $connection->linkedAccounts
                ->filter(fn (Account $account) => $account->external_account_uid !== null)
                ->map(fn (Account $account) => [
                    'id' => $account->id,
                    'name' => $account->name,
                    'external_account_uid' => $account->external_account_uid,
                    'sync_from_date' => $account->sync_from_date?->toDateString(),
                ])->values()->all(),
            'created_at' => $connection->created_at?->toIso8601String(),
            'updated_at' => $connection->updated_at?->toIso8601String(),
        ];
    }
}
