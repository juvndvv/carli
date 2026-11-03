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

/**
 * The measurement reminder: says what is still missing today (the weight, the tape measurements or both)
 * and opens the screen for the first of them.
 */
final class WeighReminder extends Notification implements ApnsNotification, ShouldQueue
{
    use Queueable;

    public const string TYPE = 'weigh_reminder';

    public const string URL = '/salud/pesarse';

    public const string BODY_URL = '/salud/medirse';

    /**
     * @param  list<'weight'|'body'>  $missing
     */
    public function __construct(public readonly array $missing = ['weight']) {}

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
            'url' => $this->url(),
        ];
    }

    public function toApns(User $notifiable): ApnsMessage
    {
        return new ApnsMessage(
            title: $this->title(),
            body: $this->body(),
            url: $this->url(),
            threadId: HealthSettings::MODULE.'.'.self::TYPE,
        );
    }

    private function weight(): bool
    {
        return in_array('weight', $this->missing, true);
    }

    private function measures(): bool
    {
        return in_array('body', $this->missing, true);
    }

    private function url(): string
    {
        return $this->weight() ? self::URL : self::BODY_URL;
    }

    private function title(): string
    {
        return match (true) {
            $this->weight() && $this->measures() => 'Hora de pesarse y medirse',
            $this->measures() => 'Hora de medirse',
            default => 'Hora de pesarse',
        };
    }

    private function body(): string
    {
        return match (true) {
            $this->weight() && $this->measures() => 'Hoy te faltan el peso y las medidas del cuerpo.',
            $this->measures() => 'Coge la cinta y apunta tus medidas del cuerpo en carli.',
            default => 'Súbete a la báscula descalzo con carli abierta.',
        };
    }
}
