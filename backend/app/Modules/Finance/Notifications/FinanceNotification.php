<?php

namespace App\Modules\Finance\Notifications;

use App\Core\Notifications\NotificationChannels;
use App\Models\User;
use App\Modules\Finance\Domain\Enums\NotificationType;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;
use NotificationChannels\WebPush\WebPushMessage;

abstract class FinanceNotification extends Notification implements ShouldQueue
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

    public function toWebPush(User $notifiable, Notification $notification): WebPushMessage
    {
        return (new WebPushMessage)
            ->title($this->title())
            ->body($this->body())
            ->icon('/icons/icon-192x192.png')
            ->tag(self::MODULE.'.'.$this->type()->value)
            ->data(['url' => $this->url(), 'onActionClick' => ['default' => ['operation' => 'navigateLastFocusedOrOpen', 'url' => $this->url()]]]);
    }
}
