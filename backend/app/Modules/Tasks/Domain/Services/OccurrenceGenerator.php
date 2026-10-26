<?php

namespace App\Modules\Tasks\Domain\Services;

use App\Models\User;
use App\Modules\Tasks\Domain\Enums\SkipReason;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Enums\TemplatePolicy;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

final class OccurrenceGenerator
{
    /** @var array<string, string> */
    private array $caughtUp = [];

    public function catchUpAll(?CarbonImmutable $today = null): int
    {
        $today ??= TaskCalendar::today();
        $created = 0;

        $this->due($today)->withoutGlobalScopes()->orderBy('id')->each(function (TaskTemplate $template) use ($today, &$created): void {
            $created += $this->generate($template, $today);
        });

        return $created;
    }

    public function catchUp(User $user, ?CarbonImmutable $today = null): int
    {
        $today ??= TaskCalendar::today();

        if (($this->caughtUp[$user->id] ?? null) === $today->toDateString()) {
            return 0;
        }

        $created = 0;
        foreach ($this->due($today)->ownedBy($user)->orderBy('id')->get() as $template) {
            $created += $this->generate($template, $today);
        }

        $this->caughtUp[$user->id] = $today->toDateString();

        return $created;
    }

    public function forget(User|string $user): void
    {
        unset($this->caughtUp[$user instanceof User ? $user->id : $user]);
    }

    public function generate(TaskTemplate $template, ?CarbonImmutable $today = null): int
    {
        $today ??= TaskCalendar::today();

        return DB::transaction(function () use ($template, $today): int {
            $locked = TaskTemplate::query()->withoutGlobalScopes()->whereKey($template->id)->lockForUpdate()->first();

            if ($locked === null || $locked->isPaused()) {
                return 0;
            }

            $created = $locked->isAfterDone() ? $this->generateAfterDone($locked, $today) : $this->generateScheduled($locked, $today);
            $template->setRawAttributes($locked->getAttributes(), true);

            return $created;
        });
    }

    /**
     * @return Builder<TaskTemplate>
     */
    private function due(CarbonImmutable $today): Builder
    {
        $date = $today->toDateString();

        return TaskTemplate::query()->active()->where(fn (Builder $query) => $query
            ->where(fn (Builder $scheduled) => $scheduled->whereNotNull('rrule')->where(fn (Builder $window) => $window
                ->whereNull('generated_through')
                ->orWhereRaw('generated_through < ?::date + lead_days', [$date])))
            ->orWhere(fn (Builder $afterDone) => $afterDone->whereNotNull('after_done_interval_days')
                ->whereNotNull('next_due_date')
                ->whereRaw('next_due_date <= ?::date + lead_days', [$date])));
    }

    private function generateScheduled(TaskTemplate $template, CarbonImmutable $today): int
    {
        $horizon = $today->addDays($template->lead_days);
        $from = $template->generated_through?->addDay() ?? $template->dtstart;
        $dates = $template->recurrence()?->between($from, $horizon) ?? [];

        $template->generated_through = $horizon;

        if ($dates === []) {
            $template->save();

            return 0;
        }

        $keys = array_map(fn (CarbonImmutable $date) => $date->toDateString(), $dates);
        $existing = Task::query()->withoutGlobalScopes()->where('template_id', $template->id)
            ->whereIn('occurrence_date', $keys)->pluck('occurrence_date')
            ->map(fn (CarbonImmutable $date) => $date->toDateString())->all();
        $exceptions = $template->exceptions()->whereIn('date', $keys)->pluck('date')
            ->map(fn (CarbonImmutable $date) => $date->toDateString())->all();

        $pending = array_values(array_filter($dates, fn (CarbonImmutable $date) => ! in_array($date->toDateString(), $existing, true)));
        $playable = array_values(array_filter($pending, fn (CarbonImmutable $date) => ! in_array($date->toDateString(), $exceptions, true)));
        $latest = $playable === [] ? null : end($playable);
        $replace = $template->policy === TemplatePolicy::Replace;
        $created = 0;

        if ($replace && $latest !== null) {
            $this->replaceOpen($template);
        }

        foreach ($pending as $date) {
            $key = $date->toDateString();

            if (in_array($key, $exceptions, true)) {
                $this->record($template, $date, SkipReason::Manual);
            } elseif ($replace && $key !== $latest?->toDateString()) {
                $this->record($template, $date, $date->lt($today) ? SkipReason::Missed : SkipReason::Replaced);
            } else {
                $this->open($template, $date);
                $created++;
            }
        }

        $template->save();

        return $created;
    }

    private function generateAfterDone(TaskTemplate $template, CarbonImmutable $today): int
    {
        $date = $template->next_due_date;

        if ($date === null || $date->gt($today->addDays($template->lead_days))) {
            return 0;
        }

        $template->next_due_date = null;

        $exhausted = ($template->until !== null && $date->gt($template->until))
            || ($template->count !== null && $template->tasks()->count() >= $template->count);
        $hasOpen = $template->tasks()->where('status', TaskStatus::Open->value)->exists();
        $taken = $template->tasks()->whereDate('occurrence_date', $date->toDateString())->exists();

        if ($exhausted || $hasOpen || $taken) {
            $template->save();

            return 0;
        }

        $this->open($template, $date);
        $template->save();

        return 1;
    }

    private function replaceOpen(TaskTemplate $template): void
    {
        Task::query()->withoutGlobalScopes()
            ->where('template_id', $template->id)
            ->where('status', TaskStatus::Open->value)
            ->update(['status' => TaskStatus::Skipped->value, 'skip_reason' => SkipReason::Replaced->value, 'skipped_at' => now(), 'updated_at' => now()]);
    }

    private function open(TaskTemplate $template, CarbonImmutable $date): Task
    {
        $task = $this->make($template, $date);
        $task->save();

        foreach ($template->subtasks as $position => $title) {
            $task->subtasks()->create(['title' => $title, 'sort' => $position]);
        }

        return $task;
    }

    private function record(TaskTemplate $template, CarbonImmutable $date, SkipReason $reason): void
    {
        $task = $this->make($template, $date);
        $task->status = TaskStatus::Skipped;
        $task->skip_reason = $reason;
        $task->skipped_at = now()->toImmutable();
        $task->save();
    }

    private function make(TaskTemplate $template, CarbonImmutable $date): Task
    {
        $task = new Task([
            'list_id' => $template->list_id,
            'template_id' => $template->id,
            'occurrence_date' => $date->toDateString(),
            'title' => $template->title,
            'notes' => $template->notes,
            'due_date' => $date->toDateString(),
            'due_time' => $template->due_time,
            'important' => $template->important,
        ]);
        $task->user_id = $template->user_id;

        return $task;
    }
}
