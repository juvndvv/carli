<?php

namespace App\Core\Notifications;

use App\Core\Modules\ModuleRegistry;
use App\Core\Push\ApnsChannel;
use App\Core\Push\ApnsConfiguration;
use App\Models\User;

final class NotificationChannels
{
    public const string DATABASE = 'database';

    public const string PUSH = ApnsChannel::class;

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

        if ($preference['push'] && self::canPush($user)) {
            $channels[] = self::PUSH;
        }

        return $channels;
    }

    public static function canPush(User $user): bool
    {
        return ApnsConfiguration::isConfigured() && $user->pushDevices()->exists();
    }
}
