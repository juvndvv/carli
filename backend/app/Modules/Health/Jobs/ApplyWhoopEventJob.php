<?php

namespace App\Modules\Health\Jobs;

use App\Modules\Health\Domain\WhoopSync;
use App\Modules\Health\Models\WhoopAccount;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;

/**
 * A webhook only says what changed; this fetches the record (or deletes it) outside the request.
 */
final class ApplyWhoopEventJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable;

    /** A failed fetch is not retried: the hourly sync picks it up. */
    public int $tries = 1;

    public function __construct(
        public readonly string $accountId,
        public readonly string $type,
        public readonly string $id,
    ) {}

    public function handle(WhoopSync $sync): void
    {
        $account = WhoopAccount::query()->find($this->accountId);

        if ($account instanceof WhoopAccount && ! $account->needsReconnect()) {
            $sync->event($account, $this->type, $this->id);
        }
    }
}
