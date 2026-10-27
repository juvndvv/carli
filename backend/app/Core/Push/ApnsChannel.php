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

        // Laravel gives every channel the same id, so the tap can mark the inbox entry as read.
        $message = $notification->toApns($notifiable)->withNotificationId($notification->id);

        foreach ($notifiable->pushDevices()->get() as $device) {
            if ($this->client->send($device->token, $device->environment, $message) === ApnsDelivery::Unregistered) {
                $device->delete();
            }
        }
    }
}
