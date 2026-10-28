<?php

namespace App\Modules\Health\Console;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Domain\HealthSettings;
use App\Modules\Health\Domain\MeasurementService;
use App\Modules\Health\Notifications\WeighReminder;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

final class WeighRemindersCommand extends Command
{
    protected $signature = 'health:weigh-reminders';

    protected $description = 'Avisa para pesarse a la hora y los días elegidos, si aún no hay pesada hoy';

    public function handle(ModuleRegistry $modules, HealthSettings $settings, MeasurementService $measurements): int
    {
        $now = CarbonImmutable::now(HabitCalendar::TIMEZONE);
        $sent = 0;

        User::query()->each(function (User $user) use ($modules, $settings, $measurements, $now, &$sent): void {
            if (! $modules->isEnabledFor($user, HealthSettings::MODULE)) {
                return;
            }

            $config = $settings->for($user);
            $due = $config['reminder_enabled']
                && $config['reminder_time'] === $now->format('H:i')
                && in_array($now->dayOfWeekIso, $config['reminder_days'], true);

            if (! $due || $measurements->weighedOn($user, $now)) {
                return;
            }

            $user->notify(new WeighReminder);
            $sent++;
        });

        $this->info("Recordatorios enviados: {$sent}");

        return self::SUCCESS;
    }
}
