<?php

namespace App\Core\Push;

use App\Models\User;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Tells the user's widgets to reload. Unique per user and delayed, so a burst of
 * changes (a bank import, a bulk edit) costs one push from the widget budget.
 */
final class RefreshWidgets implements ShouldBeUnique, ShouldQueue
{
    use Queueable;

    public const int DELAY_SECONDS = 20;

    public int $tries = 1;

    public int $uniqueFor = 120;

    public function __construct(public readonly string $userId)
    {
        $this->afterCommit();
        $this->delay(self::DELAY_SECONDS);
    }

    public function uniqueId(): string
    {
        return $this->userId;
    }

    public function handle(ApnsClient $client): void
    {
        if (! ApnsConfiguration::isConfigured()) {
            return;
        }

        $user = User::query()->find($this->userId);

        foreach ($user?->widgetPushDevices()->get() ?? [] as $device) {
            if ($client->refreshWidgets($device->token, $device->environment) === ApnsDelivery::Unregistered) {
                $device->delete();
            }
        }
    }
}
