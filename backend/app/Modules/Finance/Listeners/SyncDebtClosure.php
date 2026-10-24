<?php

namespace App\Modules\Finance\Listeners;

use App\Modules\Finance\Domain\Services\DebtService;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\Transaction;

final readonly class SyncDebtClosure
{
    public function __construct(private DebtService $debts) {}

    public function handle(TransactionSaved $event): void
    {
        $transaction = Transaction::query()->withTrashed()->ownedBy($event->userId)->whereKey($event->transactionId)->first();

        if ($transaction === null || $transaction->debt_id === null) {
            return;
        }

        $debt = Debt::query()->ownedBy($event->userId)->whereKey($transaction->debt_id)->first();

        if ($debt === null) {
            return;
        }

        if ($transaction->trashed()) {
            $this->debts->reopenIfOutstanding($debt);
        } else {
            $this->debts->closeIfSettled($debt);
        }
    }
}
