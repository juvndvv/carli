<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\DebtDirection;
use App\Modules\Finance\Domain\Enums\NotificationType;
use App\Modules\Finance\Domain\ValueObjects\Money;

final class DebtReminder extends FinanceNotification
{
    public function __construct(
        public readonly string $debtId,
        public readonly string $name,
        public readonly DebtDirection $direction,
        public readonly int $pendingCents,
        public readonly int $daysUntil,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::DebtReminder;
    }

    public function title(): string
    {
        $action = $this->direction === DebtDirection::IOwe ? 'Pago' : 'Cobro';

        return "{$action} pendiente: {$this->name}";
    }

    public function body(): string
    {
        $amount = Money::ofCents($this->pendingCents)->format();

        return $this->direction === DebtDirection::IOwe
            ? "Quedan {$amount} por pagar; vence ".UpcomingCharge::when($this->daysUntil).'.'
            : "Te deben {$amount}; vence ".UpcomingCharge::when($this->daysUntil).'.';
    }

    public function url(): string
    {
        return '/finanzas/deudas';
    }

    public function context(): array
    {
        return ['debt_id' => $this->debtId];
    }
}
