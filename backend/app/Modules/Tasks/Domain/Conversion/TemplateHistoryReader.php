<?php

namespace App\Modules\Tasks\Domain\Conversion;

use App\Models\User;
use App\Modules\Tasks\Domain\Enums\SkipReason;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;
use App\Modules\Tasks\Models\TaskTemplateException;

final class TemplateHistoryReader
{
    public function read(User $user, string $templateId): ?TemplateHistory
    {
        $template = TaskTemplate::query()->ownedBy($user)->with('exceptions')->find($templateId);

        if (! $template instanceof TaskTemplate) {
            return null;
        }

        $today = TaskCalendar::today();
        $occurrences = [];

        foreach ($template->exceptions as $exception) {
            /** @var TaskTemplateException $exception */
            if ($exception->date->lte($today)) {
                $occurrences[$exception->date->toDateString()] = TemplateHistory::SKIPPED;
            }
        }

        $tasks = $template->tasks()->whereNotNull('occurrence_date')->whereDate('occurrence_date', '<=', $today->toDateString())->get();

        foreach ($tasks as $task) {
            /** @var Task $task */
            if ($task->isOpen() && $task->occurrence_date?->gte($today)) {
                continue;
            }

            $occurrences[(string) $task->occurrence_date?->toDateString()] = match (true) {
                $task->status === TaskStatus::Done => TemplateHistory::DONE,
                $task->status === TaskStatus::Skipped && $task->skip_reason === SkipReason::Manual => TemplateHistory::SKIPPED,
                default => TemplateHistory::MISSED,
            };
        }

        ksort($occurrences);

        return new TemplateHistory(
            templateId: $template->id,
            title: $template->title,
            rrule: $template->rrule,
            dtstart: $template->dtstart,
            afterDone: $template->isAfterDone(),
            paused: $template->isPaused(),
            occurrences: $occurrences,
        );
    }
}
