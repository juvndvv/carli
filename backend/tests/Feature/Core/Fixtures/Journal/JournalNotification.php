<?php

namespace Tests\Feature\Core\Fixtures\Journal;

use App\Core\Notifications\NotificationChannels;
use App\Models\User;
use Illuminate\Notifications\Notification;
use NotificationChannels\WebPush\WebPushMessage;

class JournalNotification extends Notification
{
    public function __construct(private readonly string $type = 'daily_reminder') {}

    /**
     * @return list<string>
     */
    public function via(User $notifiable): array
    {
        return NotificationChannels::for($notifiable, 'journal', $this->type);
    }

    /**
     * @return array<string, string>
     */
    public function toArray(User $notifiable): array
    {
        return ['module' => 'journal', 'type' => $this->type, 'title' => 'Escribe hoy', 'body' => 'Tu diario te espera', 'url' => '/diario'];
    }

    public function toWebPush(User $notifiable, Notification $notification): WebPushMessage
    {
        return (new WebPushMessage)->title('Escribe hoy')->body('Tu diario te espera')->data(['url' => '/diario']);
    }
}
