<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;
use App\Modules\Finance\Domain\ValueObjects\Money;

final class RecurringPending extends FinanceNotification
{
    public function __construct(
        public readonly string $ruleId,
        public readonly string $transactionId,
        public readonly string $name,
        public readonly int $amountCents,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::RecurringPending;
    }

    public function title(): string
    {
        return "Confirma {$this->name}";
    }

    public function body(): string
    {
        return 'Hoy toca '.Money::ofCents(abs($this->amountCents))->format().'. Confírmalo o ajusta el importe.';
    }

    public function url(): string
    {
        return '/finanzas/recurrentes';
    }

    public function context(): array
    {
        return ['rule_id' => $this->ruleId, 'transaction_id' => $this->transactionId];
    }
}
