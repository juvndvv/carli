<?php

namespace App\Modules\Finance\Http\Middleware;

use App\Models\User;
use App\Modules\Finance\Domain\Services\FinanceBootstrapper;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final readonly class EnsureFinanceInitialized
{
    public function __construct(private FinanceBootstrapper $bootstrapper) {}

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user instanceof User) {
            $this->bootstrapper->ensure($user);
        }

        return $next($request);
    }
}
