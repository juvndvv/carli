<?php

namespace App\Modules\Finance\Listeners;

use App\Modules\Finance\Domain\Services\GoalService;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Models\Transaction;

final readonly class CheckGoalMilestones
{
    public function __construct(private GoalService $goals) {}

    public function handle(TransactionSaved $event): void
    {
        $transaction = Transaction::query()->withTrashed()->ownedBy($event->userId)->whereKey($event->transactionId)->first();

        if ($transaction !== null) {
            $this->goals->checkGoalsForAccount($event->userId, $transaction->account_id);
        }
    }
}
