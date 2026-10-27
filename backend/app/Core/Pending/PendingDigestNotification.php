<?php

namespace App\Core\Pending;

use App\Core\Notifications\CoreNotificationTypes;
use App\Core\Notifications\NotificationChannels;
use App\Core\Push\ApnsMessage;
use App\Core\Push\ApnsNotification;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

final class PendingDigestNotification extends Notification implements ApnsNotification, ShouldQueue
{
    use Queueable;

    public const string URL = '/pendientes';

    /**
     * @param  list<string>  $phrases
     * @param  list<string>  $lines
     */
    public function __construct(
        public readonly int $total,
        public readonly array $phrases,
        public readonly array $lines = [],
    ) {}

    public const string LINES_ONLY_URL = '/habitos/hoy';

    public function title(): string
    {
        return $this->onlyLines() ? 'Hábitos de hoy' : 'Pendientes por revisar';
    }

    public function url(): string
    {
        return $this->onlyLines() ? self::LINES_ONLY_URL : self::URL;
    }

    private function onlyLines(): bool
    {
        return $this->total <= 0 && $this->phrases === [] && $this->lines !== [];
    }

    public function body(): string
    {
        if ($this->onlyLines()) {
            return implode('. ', $this->lines);
        }

        $phrases = $this->phrases === [] ? ["{$this->total} pendientes"] : $this->phrases;
        $last = array_pop($phrases);

        return implode('. ', ['Tienes '.($phrases === [] ? $last : implode(', ', $phrases).' y '.$last), ...$this->lines]);
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
            'url' => $this->url(),
            'total' => $this->total,
        ];
    }

    public function toApns(User $notifiable): ApnsMessage
    {
        return new ApnsMessage(
            title: $this->title(),
            body: $this->body(),
            url: $this->url(),
            threadId: CoreNotificationTypes::MODULE.'.'.CoreNotificationTypes::PENDING_DIGEST,
        );
    }
}
