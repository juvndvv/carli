<?php

namespace App\Modules\Finance\Jobs;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\BankConnectionStatus;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\BankConnection;
use App\Modules\Finance\Notifications\BankConsentExpiring;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class CheckBankConsentExpiry implements ShouldQueue
{
    use Queueable;

    public const array NOTICE_DAYS = [7, 1];

    public int $sent = 0;

    public int $expired = 0;

    public function handle(): void
    {
        $now = CarbonImmutable::now();
        $today = SpanishCalendar::today();

        $connections = BankConnection::query()->withoutGlobalScopes()->syncable()->get();

        foreach ($connections as $connection) {
            if ($connection->valid_until->lessThanOrEqualTo($now)) {
                $connection->forceFill(['status' => BankConnectionStatus::Expired])->save();
                $this->expired++;

                continue;
            }

            $daysLeft = (int) $today->diffInDays(SpanishCalendar::date($connection->valid_until->setTimezone(SpanishCalendar::TIMEZONE)));
            $threshold = self::threshold($daysLeft);

            if ($threshold === null || ($connection->expiry_notice_days !== null && $connection->expiry_notice_days <= $threshold)) {
                continue;
            }

            $connection->forceFill(['expiry_notice_days' => $threshold])->save();
            User::query()->find($connection->user_id)?->notify(new BankConsentExpiring($connection->id, $connection->aspsp_name, max(1, $daysLeft)));
            $this->sent++;
        }
    }

    public static function threshold(int $daysLeft): ?int
    {
        foreach (array_reverse(self::NOTICE_DAYS) as $days) {
            if ($daysLeft <= $days) {
                return $days;
            }
        }

        return null;
    }
}
