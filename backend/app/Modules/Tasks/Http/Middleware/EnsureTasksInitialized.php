<?php

namespace App\Modules\Tasks\Http\Middleware;

use App\Models\User;
use App\Modules\Tasks\Domain\Services\TaskListService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final readonly class EnsureTasksInitialized
{
    public function __construct(private TaskListService $lists) {}

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user instanceof User) {
            $this->lists->defaultFor($user);
        }

        return $next($request);
    }
}
