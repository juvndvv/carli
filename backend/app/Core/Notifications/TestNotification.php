<?php

namespace App\Core\Notifications;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use NotificationChannels\WebPush\WebPushMessage;

class TestNotification extends Notification
{
    use Queueable;

    private const string TITLE = 'Notificación de prueba';

    private const string BODY = 'Si ves esto, las notificaciones funcionan correctamente.';

    private const string URL = '/ajustes';

    /**
     * @return list<string>
     */
    public function via(User $notifiable): array
    {
        $channels = [NotificationChannels::DATABASE];

        if (WebPushConfiguration::isConfigured() && $notifiable->pushSubscriptions()->exists()) {
            $channels[] = NotificationChannels::PUSH;
        }

        return $channels;
    }

    /**
     * @return array{module: string, type: string, title: string, body: string, url: string}
     */
    public function toArray(User $notifiable): array
    {
        return [
            'module' => 'core',
            'type' => 'test',
            'title' => self::TITLE,
            'body' => self::BODY,
            'url' => self::URL,
        ];
    }

    public function toWebPush(User $notifiable, Notification $notification): WebPushMessage
    {
        return (new WebPushMessage)
            ->title(self::TITLE)
            ->body(self::BODY)
            ->icon('/icons/icon-192x192.png')
            ->data(['url' => self::URL, 'onActionClick' => ['default' => ['operation' => 'navigateLastFocusedOrOpen', 'url' => self::URL]]]);
    }
}
