<?php

namespace App\Core\Notifications;

use App\Core\Push\ApnsMessage;
use App\Core\Push\ApnsNotification;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class TestNotification extends Notification implements ApnsNotification
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

        if (NotificationChannels::canPush($notifiable)) {
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

    public function toApns(User $notifiable): ApnsMessage
    {
        return new ApnsMessage(title: self::TITLE, body: self::BODY, url: self::URL);
    }
}
