<?php

namespace App\Modules\Tasks\Domain\Services;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use App\Modules\Tasks\Domain\Enums\TemplatePolicy;
use App\Modules\Tasks\Models\TaskList;

final readonly class TasksSettings
{
    public const string MODULE = 'tasks';

    public function __construct(private ModuleRegistry $modules) {}

    public function defaultListId(User $user): ?string
    {
        $id = $this->modules->settingsFor($user, self::MODULE)['default_list_id'] ?? null;

        if (! is_string($id) || $id === '') {
            return null;
        }

        return TaskList::query()->ownedBy($user)->active()->whereKey($id)->exists() ? $id : null;
    }

    public function defaultPolicy(User $user): TemplatePolicy
    {
        $policy = $this->modules->settingsFor($user, self::MODULE)['default_policy'] ?? null;

        return TemplatePolicy::tryFrom(is_string($policy) ? $policy : '') ?? TemplatePolicy::Replace;
    }
}
