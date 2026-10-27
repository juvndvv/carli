<?php

namespace App\Modules\Habits\Http\Controllers;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use App\Modules\Habits\Domain\Services\HabitReport;
use App\Modules\Habits\Domain\Services\TemplateConversion;
use App\Modules\Habits\Http\Requests\ConvertTemplateRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class ConversionController extends HabitsController
{
    public function __construct(
        private readonly TemplateConversion $conversion,
        private readonly HabitReport $report,
        private readonly ModuleRegistry $modules,
    ) {}

    public function preview(Request $request, string $template): JsonResponse
    {
        $user = $this->tasksUser($request);

        return response()->json(['data' => $this->conversion->preview($user, $template)]);
    }

    public function store(ConvertTemplateRequest $request): JsonResponse
    {
        $user = $this->tasksUser($request);
        /** @var array{name?: string|null, icon?: string|null, show_in_tasks?: bool|null} $overrides */
        $overrides = array_filter($request->safe()->only(['name', 'icon', 'show_in_tasks']), fn (mixed $value) => $value !== null);
        $habit = $this->conversion->convert($user, (string) $request->validated('template_id'), $overrides);

        return response()->json(['data' => $this->report->detail($habit)], 201);
    }

    private function tasksUser(Request $request): User
    {
        $user = $this->user($request);

        if (! $this->modules->isEnabledFor($user, 'tasks')) {
            abort(404);
        }

        return $user;
    }
}
