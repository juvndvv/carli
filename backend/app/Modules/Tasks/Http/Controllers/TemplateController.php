<?php

namespace App\Modules\Tasks\Http\Controllers;

use App\Modules\Tasks\Domain\Services\TemplateService;
use App\Modules\Tasks\Domain\Support\TaskCalendar;
use App\Modules\Tasks\Http\Requests\PreviewTemplateRequest;
use App\Modules\Tasks\Http\Requests\StoreTemplateRequest;
use App\Modules\Tasks\Http\Requests\TemplateDateRequest;
use App\Modules\Tasks\Http\Resources\TemplateResource;
use App\Modules\Tasks\Models\TaskTemplate;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class TemplateController extends TasksController
{
    public function __construct(private readonly TemplateService $templates) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return TemplateResource::collection(
            TaskTemplate::query()->ownedBy($this->user($request))
                ->with(['list', 'exceptions'])
                ->orderByRaw('paused_at IS NOT NULL')
                ->orderBy('title')
                ->get()
        );
    }

    public function store(StoreTemplateRequest $request): JsonResponse
    {
        return (new TemplateResource($this->templates->create($request->tasksUser(), $request->validated())))->response()->setStatusCode(201);
    }

    public function show(TaskTemplate $template): TemplateResource
    {
        $this->authorizeOwner('view', $template);

        return new TemplateResource($template);
    }

    public function update(StoreTemplateRequest $request, TaskTemplate $template): TemplateResource
    {
        $this->authorizeOwner('update', $template);

        return new TemplateResource($this->templates->update($template, $request->safe()->except('apply_to_open'), $request->boolean('apply_to_open')));
    }

    public function destroy(Request $request, TaskTemplate $template): Response
    {
        $this->authorizeOwner('delete', $template);
        $this->templates->delete($template, $request->boolean('delete_open'));

        return response()->noContent();
    }

    public function pause(TaskTemplate $template): TemplateResource
    {
        $this->authorizeOwner('update', $template);

        return new TemplateResource($this->templates->pause($template));
    }

    public function resume(TaskTemplate $template): TemplateResource
    {
        $this->authorizeOwner('update', $template);

        return new TemplateResource($this->templates->resume($template));
    }

    public function skip(TemplateDateRequest $request, TaskTemplate $template): TemplateResource
    {
        $this->authorizeOwner('update', $template);
        $this->templates->skipOccurrence($template, TaskCalendar::date((string) $request->validated('date')));

        return new TemplateResource($template->refresh());
    }

    public function unskip(TemplateDateRequest $request, TaskTemplate $template): TemplateResource
    {
        $this->authorizeOwner('update', $template);
        $this->templates->unskipOccurrence($template, TaskCalendar::date((string) $request->validated('date')));

        return new TemplateResource($template->refresh());
    }

    public function history(TaskTemplate $template): JsonResponse
    {
        $this->authorizeOwner('view', $template);

        return response()->json(['data' => $this->templates->history($template)]);
    }

    public function preview(PreviewTemplateRequest $request): JsonResponse
    {
        /** @var array{rrule?: string|null, after_done_interval_days?: int|null, dtstart?: string|null, until?: string|null, count?: int|null} $frequency */
        $frequency = $request->validated();

        return response()->json(['data' => $this->templates->preview($frequency)]);
    }
}
