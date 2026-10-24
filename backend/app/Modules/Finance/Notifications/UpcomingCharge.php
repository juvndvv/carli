<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;
use App\Modules\Finance\Domain\ValueObjects\Money;

final class UpcomingCharge extends FinanceNotification
{
    public function __construct(
        public readonly string $ruleId,
        public readonly string $name,
        public readonly int $amountCents,
        public readonly int $daysUntil,
        public readonly string $date,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::UpcomingCharge;
    }

    public function title(): string
    {
        return $this->name.' '.Money::ofCents(abs($this->amountCents))->format().' '.self::when($this->daysUntil);
    }

    public function body(): string
    {
        return $this->amountCents < 0 ? 'Cargo recurrente previsto.' : 'Ingreso recurrente previsto.';
    }

    public function url(): string
    {
        return '/finanzas/recurrentes';
    }

    public function context(): array
    {
        return ['rule_id' => $this->ruleId, 'date' => $this->date];
    }

    public static function when(int $days): string
    {
        return match ($days) {
            0 => 'hoy',
            1 => 'mañana',
            2 => 'pasado mañana',
            default => "en {$days} días",
        };
    }
}
