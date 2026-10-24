<?php

namespace App\Core\Notifications;

use App\Core\Models\NotificationPreference;
use App\Core\Modules\ModuleManifest;
use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use Illuminate\Support\Facades\DB;

final readonly class NotificationPreferenceService
{
    public function __construct(private ModuleRegistry $modules) {}

    /**
     * @return array{push: bool, in_app: bool}|null
     */
    public function resolve(User $user, string $moduleId, string $type): ?array
    {
        $definition = $this->modules->find($moduleId)?->notificationType($type);

        if ($definition === null) {
            return null;
        }

        $stored = $user->notificationPreferences()
            ->where('module_id', $moduleId)
            ->where('type', $type)
            ->first();

        return [
            'push' => $stored->push ?? $definition->push,
            'in_app' => $stored->in_app ?? $definition->inApp,
        ];
    }

    /**
     * @return list<array{module: string, name: string, icon: string, enabled: bool, types: list<array{type: string, label: string, description: string|null, push: bool, in_app: bool, default_push: bool, default_in_app: bool}>}>
     */
    public function grouped(User $user): array
    {
        $stored = $user->notificationPreferences()->get()
            ->keyBy(fn (NotificationPreference $preference) => $preference->module_id.'.'.$preference->type);

        $groups = [];

        foreach ($this->modulesWithNotifications() as $manifest) {
            $types = [];

            foreach ($manifest->notifications as $definition) {
                $preference = $stored->get($manifest->id.'.'.$definition->type);

                $types[] = [
                    'type' => $definition->type,
                    'label' => $definition->label,
                    'description' => $definition->description,
                    'push' => $preference->push ?? $definition->push,
                    'in_app' => $preference->in_app ?? $definition->inApp,
                    'default_push' => $definition->push,
                    'default_in_app' => $definition->inApp,
                ];
            }

            $groups[] = [
                'module' => $manifest->id,
                'name' => $manifest->name,
                'icon' => $manifest->icon,
                'enabled' => $this->modules->isEnabledFor($user, $manifest->id),
                'types' => $types,
            ];
        }

        return $groups;
    }

    /**
     * @param  list<array{module: string, type: string, push: bool, in_app: bool}>  $preferences
     */
    public function update(User $user, array $preferences): void
    {
        DB::transaction(function () use ($user, $preferences): void {
            foreach ($preferences as $preference) {
                NotificationPreference::query()->updateOrCreate(
                    ['user_id' => $user->id, 'module_id' => $preference['module'], 'type' => $preference['type']],
                    ['push' => $preference['push'], 'in_app' => $preference['in_app']],
                );
            }
        });
    }

    public function isKnownType(string $moduleId, string $type): bool
    {
        $manifest = $this->modules->find($moduleId);

        return $manifest !== null && $manifest->available && $manifest->notificationType($type) !== null;
    }

    /**
     * @return list<ModuleManifest>
     */
    private function modulesWithNotifications(): array
    {
        return array_values(array_filter(
            $this->modules->available(),
            fn (ModuleManifest $manifest) => $manifest->notifications !== [],
        ));
    }
}
