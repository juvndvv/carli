<?php

namespace App\Modules\Tasks\Http\Resources;

use App\Core\Recurrence\RecurrenceDescriber;
use App\Modules\Tasks\Domain\Enums\TaskStatus;
use App\Modules\Tasks\Domain\Services\TemplateService;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Models\TaskTemplate;
use App\Modules\Tasks\Models\TaskTemplateException;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin TaskTemplate
 */
final class TemplateResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var TaskTemplate $template */
        $template = $this->resource;
        $template->loadMissing(['list', 'exceptions']);
        $service = app(TemplateService::class);
        $today = TaskCalendar::today();

        return [
            'id' => $template->id,
            'title' => $template->title,
            'notes' => $template->notes,
            'list_id' => $template->list_id,
            'list' => ['id' => $template->list->id, 'name' => $template->list->name, 'color' => $template->list->color, 'is_default' => $template->list->is_default],
            'subtasks' => $template->subtasks,
            'kind' => $template->isAfterDone() ? 'after_done' : 'schedule',
            'rrule' => $template->rrule,
            'after_done_interval_days' => $template->after_done_interval_days,
            'dtstart' => $template->dtstart->toDateString(),
            'until' => $template->until?->toDateString(),
            'count' => $template->count,
            'policy' => $template->policy->value,
            'lead_days' => $template->lead_days,
            'due_time' => TaskCalendar::time($template->due_time),
            'important' => $template->important,
            'paused' => $template->isPaused(),
            'paused_at' => $template->paused_at?->toIso8601String(),
            'frequency_text' => TemplateService::describe($template),
            'ending_text' => RecurrenceDescriber::ending($template->until, $template->count),
            'next_date' => $service->nextDate($template)?->toDateString(),
            'open_task_id' => $template->tasks()->where('status', TaskStatus::Open->value)->orderBy('due_date')->value('id'),
            'upcoming_dates' => array_map(fn ($date) => $date->toDateString(), $service->upcomingDates($template)),
            'skipped_dates' => array_values($template->exceptions
                ->filter(fn (TaskTemplateException $exception) => $exception->date->gte($today))
                ->map(fn (TaskTemplateException $exception) => $exception->date->toDateString())
                ->sort()->values()->all()),
            'created_at' => $template->created_at?->toIso8601String(),
            'updated_at' => $template->updated_at?->toIso8601String(),
        ];
    }
}
