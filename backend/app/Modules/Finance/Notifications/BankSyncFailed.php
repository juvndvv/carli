<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;

final class BankSyncFailed extends FinanceNotification
{
    public function __construct(
        public readonly string $connectionId,
        public readonly string $bankName,
        public readonly string $error,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::BankSyncFailed;
    }

    public function title(): string
    {
        return "No se pudo sincronizar {$this->bankName}";
    }

    public function body(): string
    {
        return 'Lo reintentaremos en la próxima sincronización. Revisa la conexión en Ajustes → Bancos.';
    }

    public function url(): string
    {
        return '/finanzas/ajustes/bancos';
    }

    public function context(): array
    {
        return ['connection_id' => $this->connectionId, 'error' => $this->error];
    }
}
