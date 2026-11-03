<?php

namespace App\Modules\Calendar\Notifications;

use App\Core\Notifications\NotificationChannels;
use App\Core\Push\ApnsMessage;
use App\Core\Push\ApnsNotification;
use App\Models\User;
use App\Modules\Calendar\CalendarServiceProvider;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

/**
 * Google stopped accepting an account's grant: its events stay frozen until it is connected again.
 */
final class GoogleReconnect extends Notification implements ApnsNotification, ShouldQueue
{
    use Queueable;

    public const string TYPE = 'google_reconnect';

    public const string URL = '/ajustes/calendarios';

    public function __construct(public readonly string $email) {}

    /**
     * @return list<string>
     */
    public function via(User $notifiable): array
    {
        return NotificationChannels::for($notifiable, CalendarServiceProvider::MODULE, self::TYPE);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(User $notifiable): array
    {
        return [
            'module' => CalendarServiceProvider::MODULE,
            'type' => self::TYPE,
            'title' => $this->title(),
            'body' => $this->body(),
            'url' => self::URL,
        ];
    }

    public function toApns(User $notifiable): ApnsMessage
    {
        return new ApnsMessage(
            title: $this->title(),
            body: $this->body(),
            url: self::URL,
            threadId: CalendarServiceProvider::MODULE.'.'.self::TYPE,
        );
    }

    private function title(): string
    {
        return 'Vuelve a conectar Google';
    }

    private function body(): string
    {
        return "Google ya no deja leer el calendario de {$this->email}. Conéctala otra vez en Ajustes › Calendarios.";
    }
}
