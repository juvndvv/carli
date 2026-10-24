<?php

namespace App\Modules\Finance\Events;

use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

final class TransactionSaved implements ShouldDispatchAfterCommit
{
    use Dispatchable;

    public function __construct(
        public readonly string $transactionId,
        public readonly string $userId,
    ) {}
}
