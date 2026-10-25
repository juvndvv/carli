<?php

namespace App\Core\Notifications;

use App\Core\Modules\NotificationTypeDefinition;

final class CoreNotificationTypes
{
    public const string MODULE = 'core';

    public const string NAME = 'General';

    public const string ICON = 'inbox';

    public const string PENDING_DIGEST = 'pending_digest';

    /**
     * @return array<string, NotificationTypeDefinition>
     */
    public static function all(): array
    {
        return [
            self::PENDING_DIGEST => new NotificationTypeDefinition(
                type: self::PENDING_DIGEST,
                label: 'Pendientes por revisar',
                push: true,
                inApp: true,
                description: 'Resumen diario a las 20:00, solo si tienes algo pendiente.',
            ),
        ];
    }

    public static function find(string $type): ?NotificationTypeDefinition
    {
        return self::all()[$type] ?? null;
    }
}
