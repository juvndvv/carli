<?php

namespace App\Core\Notifications;

final class WebPushConfiguration
{
    public static function isConfigured(): bool
    {
        return self::publicKey() !== null && filled(config('webpush.vapid.private_key'));
    }

    public static function publicKey(): ?string
    {
        $key = config('webpush.vapid.public_key');

        return is_string($key) && $key !== '' ? $key : null;
    }
}
