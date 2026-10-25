<?php

namespace App\Core\Pending;

use App\Core\Notifications\CoreNotificationTypes;
use App\Core\Notifications\NotificationChannels;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;
use NotificationChannels\WebPush\WebPushMessage;

final class PendingDigestNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public const string URL = '/pendientes';

    /**
     * @param  list<string>  $phrases
     */
    public function __construct(
        public readonly int $total,
        public readonly array $phrases,
    ) {}

    public function title(): string
    {
        return 'Pendientes por revisar';
    }

    public function body(): string
    {
        $phrases = $this->phrases === [] ? ["{$this->total} pendientes"] : $this->phrases;
        $last = array_pop($phrases);

        return 'Tienes '.($phrases === [] ? $last : implode(', ', $phrases).' y '.$last);
    }

    /**
     * @return list<string>
     */
    public function via(User $notifiable): array
    {
        return NotificationChannels::for($notifiable, CoreNotificationTypes::MODULE, CoreNotificationTypes::PENDING_DIGEST);
    }

    /**
     * @return array{module: string, type: string, title: string, body: string, url: string, total: int}
     */
    public function toArray(User $notifiable): array
    {
        return [
            'module' => CoreNotificationTypes::MODULE,
            'type' => CoreNotificationTypes::PENDING_DIGEST,
            'title' => $this->title(),
            'body' => $this->body(),
            'url' => self::URL,
            'total' => $this->total,
        ];
    }

    public function toWebPush(User $notifiable, Notification $notification): WebPushMessage
    {
        return (new WebPushMessage)
            ->title($this->title())
            ->body($this->body())
            ->icon('/icons/icon-192x192.png')
            ->tag(CoreNotificationTypes::MODULE.'.'.CoreNotificationTypes::PENDING_DIGEST)
            ->data(['url' => self::URL, 'onActionClick' => ['default' => ['operation' => 'navigateLastFocusedOrOpen', 'url' => self::URL]]]);
    }
}
