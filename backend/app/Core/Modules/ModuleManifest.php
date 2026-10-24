<?php

namespace App\Core\Modules;

use InvalidArgumentException;

final readonly class ModuleManifest
{
    /**
     * @param  array<string, NotificationTypeDefinition>  $notifications
     * @param  array<string, mixed>  $defaultSettings
     */
    public function __construct(
        public string $id,
        public string $name,
        public string $icon,
        public string $route,
        public bool $available,
        public ?string $description = null,
        public array $notifications = [],
        public array $defaultSettings = [],
    ) {}

    /**
     * @param  array<string, mixed>  $manifest
     */
    public static function fromArray(array $manifest, bool $available = true): self
    {
        foreach (['id', 'name', 'icon', 'route'] as $key) {
            if (! is_string($manifest[$key] ?? null) || $manifest[$key] === '') {
                throw new InvalidArgumentException("Module manifest is missing the [{$key}] key.");
            }
        }

        $notifications = [];
        foreach ((array) ($manifest['notifications'] ?? []) as $type => $definition) {
            $notifications[(string) $type] = NotificationTypeDefinition::fromArray((string) $type, (array) $definition);
        }

        return new self(
            id: $manifest['id'],
            name: $manifest['name'],
            icon: $manifest['icon'],
            route: $manifest['route'],
            available: $available,
            description: is_string($manifest['description'] ?? null) ? $manifest['description'] : null,
            notifications: $notifications,
            defaultSettings: (array) ($manifest['settings'] ?? []),
        );
    }

    public function notificationType(string $type): ?NotificationTypeDefinition
    {
        return $this->notifications[$type] ?? null;
    }
}
