<?php

namespace App\Modules\Finance\Notifications;

use App\Core\Notifications\NotificationChannels;
use App\Core\Push\ApnsMessage;
use App\Core\Push\ApnsNotification;
use App\Models\User;
use App\Modules\Finance\Domain\Enums\NotificationType;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

abstract class FinanceNotification extends Notification implements ApnsNotification, ShouldQueue
{
    use Queueable;

    public const string MODULE = 'finance';

    abstract public function type(): NotificationType;

    abstract public function title(): string;

    abstract public function body(): string;

    abstract public function url(): string;

    /**
     * @return array<string, mixed>
     */
    public function context(): array
    {
        return [];
    }

    /**
     * @return list<string>
     */
    public function via(User $notifiable): array
    {
        return NotificationChannels::for($notifiable, self::MODULE, $this->type()->value);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(User $notifiable): array
    {
        return [
            'module' => self::MODULE,
            'type' => $this->type()->value,
            'title' => $this->title(),
            'body' => $this->body(),
            'url' => $this->url(),
            ...$this->context(),
        ];
    }

    public function toApns(User $notifiable): ApnsMessage
    {
        return new ApnsMessage(
            title: $this->title(),
            body: $this->body(),
            url: $this->url(),
            threadId: self::MODULE.'.'.$this->type()->value,
        );
    }
}
