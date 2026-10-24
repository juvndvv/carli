<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;
use App\Modules\Finance\Domain\ValueObjects\Money;

final class WeeklySummary extends FinanceNotification
{
    public function __construct(
        public readonly string $rangeLabel,
        public readonly int $spentCents,
        public readonly int $incomeCents,
        public readonly int $periodSpentCents,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::WeeklySummary;
    }

    public function title(): string
    {
        return 'Tu semana en Finanzas';
    }

    public function body(): string
    {
        return "Semana {$this->rangeLabel}: gastaste ".Money::ofCents($this->spentCents)->format()
            .' e ingresaste '.Money::ofCents($this->incomeCents)->format()
            .'. Llevas '.Money::ofCents($this->periodSpentCents)->format().' en el periodo.';
    }

    public function url(): string
    {
        return '/finanzas';
    }
}
