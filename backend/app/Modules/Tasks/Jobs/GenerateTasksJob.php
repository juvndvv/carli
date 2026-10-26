<?php

namespace App\Modules\Tasks\Jobs;

use App\Modules\Tasks\Domain\Services\OccurrenceGenerator;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class GenerateTasksJob implements ShouldQueue
{
    use Queueable;

    public int $created = 0;

    public function __construct(public readonly ?string $date = null) {}

    public function handle(OccurrenceGenerator $generator): void
    {
        $this->created = $generator->catchUpAll($this->date === null ? null : TaskCalendar::date($this->date));
    }
}
