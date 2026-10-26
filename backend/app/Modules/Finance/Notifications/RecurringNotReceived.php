<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Domain\ValueObjects\Money;

final class RecurringNotReceived extends FinanceNotification
{
    public function __construct(
        public readonly string $ruleId,
        public readonly string $transactionId,
        public readonly string $name,
        public readonly int $amountCents,
        public readonly string $date,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::RecurringPending;
    }

    public function title(): string
    {
        return "{$this->name} no ha entrado";
    }

    public function body(): string
    {
        return 'Esperabas '.Money::ofCents(abs($this->amountCents))->format().' el '.SpanishCalendar::date($this->date)->format('d/m').' y no ha llegado al banco. Revísalo o confírmalo a mano.';
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
