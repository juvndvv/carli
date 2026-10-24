<?php

namespace App\Core\Http\Middleware;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final readonly class EnsureModuleEnabled
{
    public function __construct(private ModuleRegistry $modules) {}

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next, string $module): Response
    {
        $user = $request->user();

        abort_unless(
            $user instanceof User && $this->modules->isEnabledFor($user, $module),
            403,
            'El módulo está desactivado.',
        );

        return $next($request);
    }
}
