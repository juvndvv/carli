<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;

final class PayrollOverdue extends FinanceNotification
{
    public function __construct(public readonly string $periodId) {}

    public function type(): NotificationType
    {
        return NotificationType::PayrollOverdue;
    }

    public function title(): string
    {
        return '¿Has cobrado ya?';
    }

    public function body(): string
    {
        return 'Registra la nómina para empezar el nuevo periodo.';
    }

    public function url(): string
    {
        return '/finanzas/movimientos/nuevo?tipo=ingreso';
    }

    public function context(): array
    {
        return ['period_id' => $this->periodId];
    }
}
