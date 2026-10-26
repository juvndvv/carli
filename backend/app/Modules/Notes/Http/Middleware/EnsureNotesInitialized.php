<?php

namespace App\Modules\Notes\Http\Middleware;

use App\Models\User;
use App\Modules\Notes\Domain\Services\DefaultSections;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final readonly class EnsureNotesInitialized
{
    public function __construct(private DefaultSections $sections) {}

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user instanceof User) {
            $this->sections->ensure($user);
        }

        return $next($request);
    }
}
