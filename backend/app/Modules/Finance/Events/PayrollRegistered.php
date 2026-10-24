<?php

namespace App\Modules\Finance\Events;

use App\Modules\Finance\Models\Transaction;
use Illuminate\Foundation\Events\Dispatchable;

final class PayrollRegistered
{
    use Dispatchable;

    public bool $periodOpened = false;

    public function __construct(public readonly Transaction $transaction) {}
}
