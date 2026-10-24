<?php

namespace App\Core\Modules;

final readonly class NotificationTypeDefinition
{
    public function __construct(
        public string $type,
        public string $label,
        public bool $push,
        public bool $inApp,
        public ?string $description = null,
    ) {}

    /**
     * @param  array<string, mixed>  $definition
     */
    public static function fromArray(string $type, array $definition): self
    {
        return new self(
            type: $type,
            label: is_string($definition['label'] ?? null) ? $definition['label'] : $type,
            push: (bool) ($definition['push'] ?? false),
            inApp: (bool) ($definition['in_app'] ?? true),
            description: is_string($definition['description'] ?? null) ? $definition['description'] : null,
        );
    }
}
