<?php

namespace App\Core\Notifications;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use NotificationChannels\WebPush\WebPushChannel;

final class NotificationChannels
{
    public const string DATABASE = 'database';

    public const string PUSH = WebPushChannel::class;

    /**
     * @return list<string>
     */
    public static function for(User $user, string $moduleId, string $type): array
    {
        if ($moduleId !== CoreNotificationTypes::MODULE && ! app(ModuleRegistry::class)->isEnabledFor($user, $moduleId)) {
            return [];
        }

        $preference = app(NotificationPreferenceService::class)->resolve($user, $moduleId, $type)
            ?? ['push' => false, 'in_app' => true];

        $channels = [];

        if ($preference['in_app']) {
            $channels[] = self::DATABASE;
        }

        if ($preference['push'] && WebPushConfiguration::isConfigured()) {
            $channels[] = self::PUSH;
        }

        return $channels;
    }
}
