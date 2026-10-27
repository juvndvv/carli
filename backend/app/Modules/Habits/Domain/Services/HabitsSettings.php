<?php

namespace App\Modules\Habits\Domain\Services;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;

final readonly class HabitsSettings
{
    public const string MODULE = 'habits';

    public function __construct(private ModuleRegistry $modules) {}

    public function showInTasks(User $user): bool
    {
        return (bool) ($this->modules->settingsFor($user, self::MODULE)['show_in_tasks'] ?? true);
    }

    public function digestEnabled(User $user): bool
    {
        return (bool) ($this->modules->settingsFor($user, self::MODULE)['digest'] ?? true);
    }
}
