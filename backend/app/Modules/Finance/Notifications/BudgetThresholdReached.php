<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;
use App\Modules\Finance\Domain\ValueObjects\Money;

final class BudgetThresholdReached extends FinanceNotification
{
    public function __construct(
        public readonly string $categoryName,
        public readonly int $threshold,
        public readonly int $spentCents,
        public readonly int $availableCents,
        public readonly string $periodId,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::BudgetThreshold;
    }

    public function title(): string
    {
        return $this->threshold >= 100
            ? "Has superado el presupuesto de {$this->categoryName}"
            : "{$this->categoryName}: {$this->threshold} % del presupuesto";
    }

    public function body(): string
    {
        return 'Llevas '.Money::ofCents($this->spentCents)->format().' de '.Money::ofCents($this->availableCents)->format().' en este periodo.';
    }

    public function url(): string
    {
        return '/finanzas/presupuestos?periodo='.$this->periodId;
    }

    public function context(): array
    {
        return ['threshold' => $this->threshold, 'period_id' => $this->periodId];
    }
}
