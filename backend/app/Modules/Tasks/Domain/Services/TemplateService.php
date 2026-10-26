<?php

namespace App\Modules\Tasks\Domain\Services;

use App\Core\Recurrence\RecurrenceDescriber;
use App\Core\Recurrence\RecurrenceRule;
use App\Models\User;
use App\Modules\Tasks\Domain\Enums\SkipReason;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Enums\TemplatePolicy;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\Task;
use App\Modules\Tasks\Models\TaskTemplate;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class TemplateService
{
    public const int PREVIEW_SIZE = 5;

    public const int HISTORY_WINDOW = 10;

    private const array COPIED_TO_OPEN_TASKS = ['title', 'notes', 'list_id', 'due_time', 'important'];

    public function __construct(
        private readonly TaskListService $lists,
        private readonly TasksSettings $settings,
        private readonly OccurrenceGenerator $generator,
    ) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data): TaskTemplate
    {
        return DB::transaction(function () use ($user, $data): TaskTemplate {
            $today = TaskCalendar::today();
            $attributes = array_filter($this->attributes($data), fn (mixed $value, string $key) => $value !== null || ! in_array($key, ['list_id', 'policy', 'dtstart'], true), ARRAY_FILTER_USE_BOTH);
            $template = new TaskTemplate($attributes + [
                'list_id' => $this->settings->defaultListId($user) ?? $this->lists->defaultFor($user)->id,
                'policy' => $this->settings->defaultPolicy($user)->value,
                'dtstart' => $today->toDateString(),
            ]);
            $template->user_id = $user->id;
            $template->generated_through = $today->subDay();

            if ($template->isAfterDone()) {
                $template->next_due_date = $template->dtstart->max($today);
            }

            $template->save();
            $this->generator->forget($user);
            $this->generator->generate($template, $today);

            return $template;
        });
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(TaskTemplate $template, array $data, bool $applyToOpen = false): TaskTemplate
    {
        return DB::transaction(function () use ($template, $data, $applyToOpen): TaskTemplate {
            $today = TaskCalendar::today();
            $wasAfterDone = $template->isAfterDone();
            $template->fill($this->attributes($data));

            if ($template->isAfterDone() && ! $wasAfterDone) {
                $hasOpen = $template->tasks()->where('status', TaskStatus::Open->value)->exists();
                $template->next_due_date = $hasOpen ? null : $template->dtstart->max($today);
            }

            if (! $template->isAfterDone()) {
                $template->next_due_date = null;
                $template->generated_through ??= $today->subDay();
            }

            $template->save();

            if ($applyToOpen) {
                $template->tasks()->where('status', TaskStatus::Open->value)
                    ->update($template->only(self::COPIED_TO_OPEN_TASKS) + ['updated_at' => now()]);
            }

            $this->generator->forget($template->user_id);
            $this->generator->generate($template, $today);

            return $template;
        });
    }

    public function pause(TaskTemplate $template): TaskTemplate
    {
        $template->paused_at ??= now()->toImmutable();
        $template->save();

        return $template;
    }

    public function resume(TaskTemplate $template): TaskTemplate
    {
        $today = TaskCalendar::today();

        $template->paused_at = null;
        if (! $template->isAfterDone()) {
            $template->generated_through = $today->subDay();
        }
        $template->save();

        $this->generator->forget($template->user_id);
        $this->generator->generate($template, $today);

        return $template;
    }

    public function skipOccurrence(TaskTemplate $template, CarbonImmutable $date): void
    {
        DB::transaction(function () use ($template, $date): void {
            $task = $template->tasks()->whereDate('occurrence_date', $date->toDateString())->first();

            if ($task !== null) {
                if ($task->isOpen()) {
                    $task->status = TaskStatus::Skipped;
                    $task->skip_reason = SkipReason::Manual;
                    $task->skipped_at = now()->toImmutable();
                    $task->save();
                }

                if ($template->isAfterDone()) {
                    $template->next_due_date = TaskCalendar::today()->addDays((int) $template->after_done_interval_days);
                    $template->save();
                }

                return;
            }

            if ($template->isAfterDone()) {
                $template->next_due_date = $date->addDays((int) $template->after_done_interval_days);
                $template->save();

                return;
            }

            $template->exceptions()->firstOrCreate(['date' => $date->toDateString()]);
        });

        $this->generator->forget($template->user_id);
    }

    public function unskipOccurrence(TaskTemplate $template, CarbonImmutable $date): void
    {
        $template->exceptions()->whereDate('date', $date->toDateString())->delete();
        $this->generator->forget($template->user_id);
    }

    public function delete(TaskTemplate $template, bool $deleteOpen): void
    {
        DB::transaction(function () use ($template, $deleteOpen): void {
            if ($deleteOpen) {
                $template->tasks()->where('status', TaskStatus::Open->value)->delete();
            }

            $template->delete();
        });
    }

    /**
     * @return list<CarbonImmutable>
     */
    public function upcomingDates(TaskTemplate $template, ?CarbonImmutable $from = null, int $limit = self::PREVIEW_SIZE): array
    {
        $from ??= TaskCalendar::today();

        if ($template->isPaused()) {
            return [];
        }

        if ($template->isAfterDone()) {
            return $template->next_due_date === null || $template->next_due_date->lt($from) ? [] : [$template->next_due_date];
        }

        $from = $from->max($template->generated_through?->addDay() ?? $template->dtstart);
        $skipped = $template->exceptions()->pluck('date')->map(fn (CarbonImmutable $date) => $date->toDateString())->all();
        $rule = $template->recurrence();

        if ($rule === null) {
            return [];
        }

        return array_slice(array_values(array_filter(
            $rule->next($from, $limit + count($skipped)),
            fn (CarbonImmutable $date) => ! in_array($date->toDateString(), $skipped, true),
        )), 0, $limit);
    }

    public function nextDate(TaskTemplate $template): ?CarbonImmutable
    {
        $open = $template->tasks()->where('status', TaskStatus::Open->value)->orderBy('due_date')->value('due_date');

        if ($open !== null) {
            return TaskCalendar::date((string) $open);
        }

        return $this->upcomingDates($template, limit: 1)[0] ?? null;
    }

    public static function describe(TaskTemplate $template): string
    {
        if ($template->isAfterDone()) {
            return RecurrenceDescriber::afterDone((int) $template->after_done_interval_days);
        }

        $rule = $template->recurrence();

        return $rule === null ? '' : RecurrenceDescriber::describe($rule);
    }

    /**
     * @param  array{rrule?: string|null, after_done_interval_days?: int|null, dtstart?: string|null, until?: string|null, count?: int|null}  $frequency
     * @return array{description: string, ending: string|null, dates: list<string>}
     */
    public function preview(array $frequency): array
    {
        $today = TaskCalendar::today();
        $start = isset($frequency['dtstart']) ? TaskCalendar::date($frequency['dtstart']) : $today;
        $until = isset($frequency['until']) ? TaskCalendar::date($frequency['until']) : null;
        $count = $frequency['count'] ?? null;
        $ending = RecurrenceDescriber::ending($until, $count);

        if (isset($frequency['after_done_interval_days'])) {
            $days = (int) $frequency['after_done_interval_days'];
            $dates = [];
            $date = $start->max($today);
            for ($index = 0; $index < self::PREVIEW_SIZE && ($until === null || $date->lte($until)) && ($count === null || $index < $count); $index++) {
                $dates[] = $date->toDateString();
                $date = $date->addDays($days);
            }

            return ['description' => RecurrenceDescriber::afterDone($days), 'ending' => $ending, 'dates' => $dates];
        }

        $rule = RecurrenceRule::parse((string) ($frequency['rrule'] ?? ''), $start, $until, $count);

        return [
            'description' => RecurrenceDescriber::describe($rule),
            'ending' => $ending,
            'dates' => array_map(fn (CarbonImmutable $date) => $date->toDateString(), $rule->next($start->max($today), self::PREVIEW_SIZE)),
        ];
    }

    /**
     * @return array{items: list<array{task_id: string, date: string, status: string, skip_reason: string|null, completed_at: string|null}>, done: int, window: int}
     */
    public function history(TaskTemplate $template, int $limit = 30): array
    {
        $today = TaskCalendar::today();
        $tasks = $template->tasks()
            ->whereDate('occurrence_date', '<=', $today->toDateString())
            ->orderByDesc('occurrence_date')
            ->limit($limit)
            ->get();

        $resolved = $tasks->filter(fn (Task $task) => ! $task->isOpen())->take(self::HISTORY_WINDOW);

        return [
            'items' => array_values($tasks->map(fn (Task $task) => [
                'task_id' => $task->id,
                'date' => $task->occurrence_date?->toDateString() ?? '',
                'status' => $task->status->value,
                'skip_reason' => $task->skip_reason?->value,
                'completed_at' => $task->completed_at?->toIso8601String(),
            ])->all()),
            'done' => $resolved->filter(fn (Task $task) => $task->status === TaskStatus::Done)->count(),
            'window' => $resolved->count(),
        ];
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data): array
    {
        $attributes = array_intersect_key($data, array_flip([
            'title', 'notes', 'list_id', 'subtasks', 'rrule', 'dtstart', 'until', 'count',
            'after_done_interval_days', 'policy', 'lead_days', 'due_time', 'important',
        ]));

        if (isset($attributes['title']) && is_string($attributes['title'])) {
            $attributes['title'] = trim($attributes['title']);
        }

        if (isset($attributes['rrule']) && is_string($attributes['rrule'])) {
            $attributes['rrule'] = RecurrenceRule::parse($attributes['rrule'], TaskCalendar::today())->toString();
            $attributes['after_done_interval_days'] = null;
        } elseif (isset($attributes['after_done_interval_days'])) {
            $attributes['rrule'] = null;
        }

        if (isset($attributes['subtasks']) && is_array($attributes['subtasks'])) {
            $attributes['subtasks'] = array_values(array_filter(array_map(fn (mixed $title) => trim((string) $title), $attributes['subtasks']), fn (string $title) => $title !== ''));
        }

        if (array_key_exists('until', $attributes) && $attributes['until'] !== null) {
            $attributes['count'] = null;
        } elseif (array_key_exists('count', $attributes) && $attributes['count'] !== null) {
            $attributes['until'] = null;
        }

        if (isset($attributes['policy']) && $attributes['policy'] instanceof TemplatePolicy) {
            $attributes['policy'] = $attributes['policy']->value;
        }

        return $attributes;
    }
}
