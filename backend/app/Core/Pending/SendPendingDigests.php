<?php

namespace App\Core\Pending;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Cache;

final class SendPendingDigests implements ShouldQueue
{
    use Queueable;

    public const string TIMEZONE = 'Europe/Madrid';

    public int $sent = 0;

    public function __construct(public readonly ?string $date = null) {}

    public function handle(PendingRegistry $pending): void
    {
        $date = ($this->date === null ? CarbonImmutable::now(self::TIMEZONE) : CarbonImmutable::parse($this->date, self::TIMEZONE))->toDateString();

        User::query()->orderBy('id')->each(function (User $user) use ($pending, $date): void {
            $summary = $pending->summary($user);

            if ($summary['total'] <= 0 || ! Cache::add("pending-digest:{$user->id}:{$date}", true, now()->addDays(2))) {
                return;
            }

            $user->notify(new PendingDigestNotification($summary['total'], $pending->describe($user)));
            $this->sent++;
        });
    }
}
