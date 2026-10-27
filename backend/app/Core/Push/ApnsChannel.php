<?php

namespace App\Core\Push;

use App\Models\User;
use Illuminate\Notifications\Notification;

final readonly class ApnsChannel
{
    public function __construct(private ApnsClient $client) {}

    public function send(User $notifiable, Notification $notification): void
    {
        if (! $notification instanceof ApnsNotification || ! ApnsConfiguration::isConfigured()) {
            return;
        }

        $message = $notification->toApns($notifiable);

        foreach ($notifiable->pushDevices()->get() as $device) {
            if ($this->client->send($device->token, $device->environment, $message) === ApnsDelivery::Unregistered) {
                $device->delete();
            }
        }
    }
}
