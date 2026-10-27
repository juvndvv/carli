<?php

namespace Tests\Feature\Core\Fixtures\Journal;

use App\Core\Notifications\NotificationChannels;
use App\Core\Push\ApnsMessage;
use App\Core\Push\ApnsNotification;
use App\Models\User;
use Illuminate\Notifications\Notification;

class JournalNotification extends Notification implements ApnsNotification
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

    public function toApns(User $notifiable): ApnsMessage
    {
        return new ApnsMessage(title: 'Escribe hoy', body: 'Tu diario te espera', url: '/diario');
    }
}
