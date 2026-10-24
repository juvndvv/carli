<?php

namespace App\Modules\Finance\Listeners;

use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Models\Transaction;

final readonly class CheckBudgetThresholds
{
    public function __construct(private BudgetService $budgets) {}

    public function handle(TransactionSaved $event): void
    {
        $transaction = Transaction::query()->ownedBy($event->userId)->whereKey($event->transactionId)->first();

        if ($transaction !== null) {
            $this->budgets->checkThresholds($transaction);
        }
    }
}
