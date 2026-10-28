<?php

namespace App\Modules\Health\Notifications;

use App\Core\Notifications\NotificationChannels;
use App\Core\Push\ApnsMessage;
use App\Core\Push\ApnsNotification;
use App\Models\User;
use App\Modules\Health\Domain\HealthSettings;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

final class WeighReminder extends Notification implements ApnsNotification, ShouldQueue
{
    use Queueable;

    public const string TYPE = 'weigh_reminder';

    public const string URL = '/salud/pesarse';

    /**
     * @return list<string>
     */
    public function via(User $notifiable): array
    {
        return NotificationChannels::for($notifiable, HealthSettings::MODULE, self::TYPE);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(User $notifiable): array
    {
        return [
            'module' => HealthSettings::MODULE,
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
            threadId: HealthSettings::MODULE.'.'.self::TYPE,
        );
    }

    private function title(): string
    {
        return 'Hora de pesarse';
    }

    private function body(): string
    {
        return 'Súbete a la báscula descalzo con carli abierta.';
    }
}
