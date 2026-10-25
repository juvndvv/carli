<?php

namespace App\Modules\Finance\Jobs;

use App\Modules\Finance\BankSync\Data\PsuContext;
use App\Modules\Finance\BankSync\Services\BankSyncService;
use App\Modules\Finance\Models\BankConnection;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class SyncBankConnection implements ShouldBeUnique, ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public int $timeout = 300;

    public int $uniqueFor = 600;

    public function __construct(
        public readonly string $connectionId,
        public readonly ?string $psuIpAddress = null,
        public readonly ?string $psuUserAgent = null,
    ) {
        $this->afterCommit();
    }

    public function uniqueId(): string
    {
        return $this->connectionId;
    }

    public function handle(BankSyncService $sync): void
    {
        $connection = BankConnection::query()->withoutGlobalScopes()->find($this->connectionId);

        if ($connection === null) {
            return;
        }

        $psu = $this->psuIpAddress === null ? null : new PsuContext($this->psuIpAddress, $this->psuUserAgent);
        $sync->sync($connection, $psu);
    }
}
