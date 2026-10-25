<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;

final class BankConsentExpiring extends FinanceNotification
{
    public function __construct(
        public readonly string $connectionId,
        public readonly string $bankName,
        public readonly int $daysLeft,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::BankConsentExpiring;
    }

    public function title(): string
    {
        return $this->daysLeft === 1
            ? "La conexión con {$this->bankName} caduca mañana"
            : "La conexión con {$this->bankName} caduca en {$this->daysLeft} días";
    }

    public function body(): string
    {
        return 'Renuévala para seguir importando movimientos.';
    }

    public function url(): string
    {
        return '/finanzas/ajustes/bancos';
    }

    public function context(): array
    {
        return ['connection_id' => $this->connectionId, 'days_left' => $this->daysLeft];
    }
}
