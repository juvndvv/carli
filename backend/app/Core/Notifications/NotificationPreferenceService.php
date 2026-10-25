<?php

namespace App\Core\Notifications;

use App\Core\Models\NotificationPreference;
use App\Core\Modules\ModuleManifest;
use App\Core\Modules\ModuleRegistry;
use App\Core\Modules\NotificationTypeDefinition;
use App\Core\Pending\PendingRegistry;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

final readonly class NotificationPreferenceService
{
    public function __construct(
        private ModuleRegistry $modules,
        private PendingRegistry $pending,
    ) {}

    /**
     * @return array{push: bool, in_app: bool}|null
     */
    public function resolve(User $user, string $moduleId, string $type): ?array
    {
        $definition = $this->definition($moduleId, $type);

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

        if ($this->pending->hasProvidersFor($user)) {
            $groups[] = [
                'module' => CoreNotificationTypes::MODULE,
                'name' => CoreNotificationTypes::NAME,
                'icon' => CoreNotificationTypes::ICON,
                'enabled' => true,
                'types' => $this->presentTypes(CoreNotificationTypes::MODULE, CoreNotificationTypes::all(), $stored),
            ];
        }

        foreach ($this->modulesWithNotifications() as $manifest) {
            $groups[] = [
                'module' => $manifest->id,
                'name' => $manifest->name,
                'icon' => $manifest->icon,
                'enabled' => $this->modules->isEnabledFor($user, $manifest->id),
                'types' => $this->presentTypes($manifest->id, $manifest->notifications, $stored),
            ];
        }

        return $groups;
    }

    /**
     * @param  array<string, NotificationTypeDefinition>  $definitions
     * @param  Collection<string, NotificationPreference>  $stored
     * @return list<array{type: string, label: string, description: string|null, push: bool, in_app: bool, default_push: bool, default_in_app: bool}>
     */
    private function presentTypes(string $moduleId, array $definitions, Collection $stored): array
    {
        $types = [];

        foreach ($definitions as $definition) {
            $preference = $stored->get($moduleId.'.'.$definition->type);

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

        return $types;
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
        if ($moduleId === CoreNotificationTypes::MODULE) {
            return CoreNotificationTypes::find($type) !== null;
        }

        $manifest = $this->modules->find($moduleId);

        return $manifest !== null && $manifest->available && $manifest->notificationType($type) !== null;
    }

    private function definition(string $moduleId, string $type): ?NotificationTypeDefinition
    {
        if ($moduleId === CoreNotificationTypes::MODULE) {
            return CoreNotificationTypes::find($type);
        }

        return $this->modules->find($moduleId)?->notificationType($type);
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
