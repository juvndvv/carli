<?php

namespace App\Modules\Health\Domain;

use App\Core\Models\UserModule;
use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;

final readonly class HealthSettings
{
    public const string MODULE = 'health';

    public const array KEYS = ['height_cm', 'birth_date', 'sex', 'goal_kg', 'reminder_enabled', 'reminder_time', 'reminder_days'];

    public function __construct(private ModuleRegistry $modules) {}

    /**
     * @return array{height_cm: int|null, birth_date: string|null, sex: string|null, goal_kg: float|null, reminder_enabled: bool, reminder_time: string, reminder_days: list<int>, age: int|null}
     */
    public function for(User $user): array
    {
        $settings = $this->modules->settingsFor($user, self::MODULE);
        $birth = is_string($settings['birth_date'] ?? null) ? $settings['birth_date'] : null;
        $days = is_array($settings['reminder_days'] ?? null) ? $settings['reminder_days'] : [1, 2, 3, 4, 5, 6, 7];

        return [
            'height_cm' => isset($settings['height_cm']) ? (int) $settings['height_cm'] : null,
            'birth_date' => $birth,
            'sex' => is_string($settings['sex'] ?? null) ? $settings['sex'] : null,
            'goal_kg' => isset($settings['goal_kg']) ? (float) $settings['goal_kg'] : null,
            'reminder_enabled' => (bool) ($settings['reminder_enabled'] ?? false),
            'reminder_time' => is_string($settings['reminder_time'] ?? null) ? $settings['reminder_time'] : '08:00',
            'reminder_days' => array_values(array_map('intval', $days)),
            'age' => $birth === null ? null : (int) HabitCalendar::date($birth)->diffInYears(HabitCalendar::today()),
        ];
    }

    /**
     * @param  array<string, mixed>  $changes
     */
    public function update(User $user, array $changes): void
    {
        $record = UserModule::query()->firstOrNew(['user_id' => $user->id, 'module_id' => self::MODULE]);
        $record->settings = array_replace($record->settings ?? [], array_intersect_key($changes, array_flip(self::KEYS)));
        $record->save();
    }
}
