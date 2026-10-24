<?php

namespace App\Modules\Finance\Notifications;

use App\Modules\Finance\Domain\Enums\NotificationType;

final class GoalReached extends FinanceNotification
{
    public function __construct(
        public readonly string $goalName,
        public readonly string $goalId,
        public readonly int $milestone,
    ) {}

    public function type(): NotificationType
    {
        return NotificationType::GoalReached;
    }

    public function title(): string
    {
        return $this->milestone >= 100 ? "¡Objetivo conseguido: {$this->goalName}!" : "{$this->goalName}: {$this->milestone} % conseguido";
    }

    public function body(): string
    {
        return $this->milestone >= 100 ? 'Has llegado a la meta de ahorro.' : 'Sigue así, vas por buen camino.';
    }

    public function url(): string
    {
        return '/finanzas/objetivos/'.$this->goalId;
    }

    public function context(): array
    {
        return ['goal_id' => $this->goalId, 'milestone' => $this->milestone];
    }
}
