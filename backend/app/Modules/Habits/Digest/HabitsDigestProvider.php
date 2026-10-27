<?php

namespace App\Modules\Habits\Digest;

use App\Core\Pending\DigestLineProvider;
use App\Models\User;
use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Services\HabitReport;
use App\Modules\Habits\Domain\Services\HabitsSettings;
use App\Modules\Habits\Domain\Support\GoalDescriber;
use App\Modules\Habits\Domain\Support\HabitCalendar;

final readonly class HabitsDigestProvider implements DigestLineProvider
{
    public function __construct(
        private HabitReport $report,
        private HabitsSettings $settings,
    ) {}

    public function moduleId(): string
    {
        return HabitsSettings::MODULE;
    }

    public function digestLines(User $user): array
    {
        if (! $this->settings->digestEnabled($user)) {
            return [];
        }

        $today = HabitCalendar::today();
        $daily = 0;
        $atRisk = [];

        foreach ($this->report->habits($user) as $habit) {
            if ($habit->kind === HabitKind::Avoid) {
                continue;
            }

            $item = $this->report->todayItem($habit, today: $today);

            if ($item === null || $item['met']) {
                continue;
            }

            if ($item['period'] === GoalPeriod::Day->value) {
                $daily++;

                continue;
            }

            if ($habit->kind !== HabitKind::Check) {
                continue;
            }

            $missing = (int) ceil($item['target'] - $item['value']);
            $daysLeft = (int) $item['days_left'];
            $openDays = $daysLeft - ($item['today_value'] > 0 ? 1 : 0);

            if ($missing > 0 && $openDays <= $missing) {
                $atRisk[] = sprintf('%s: %s de %s, %s', $habit->name, GoalDescriber::number($item['value']), GoalDescriber::number($item['target']), $daysLeft === 1 ? 'queda 1 día' : "quedan {$daysLeft} días");
            }
        }

        $lines = match (true) {
            $daily === 1 => ['Te queda 1 hábito de hoy'],
            $daily > 1 => ["Te quedan {$daily} hábitos de hoy"],
            default => [],
        };

        return [...$lines, ...$atRisk];
    }
}
