<?php

namespace App\Modules\Calendar\Jobs;

use App\Modules\Calendar\Domain\GoogleSync;
use App\Modules\Calendar\Models\GoogleAccount;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;

final class SyncGoogleAccountJob implements ShouldBeUnique, ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable;

    public int $tries = 1;

    public int $uniqueFor = 300;

    public function __construct(public readonly string $accountId) {}

    public function uniqueId(): string
    {
        return $this->accountId;
    }

    public function handle(GoogleSync $sync): void
    {
        $account = GoogleAccount::query()->find($this->accountId);

        if ($account instanceof GoogleAccount && ! $account->needsReconnect()) {
            $sync->run($account);
        }
    }
}
