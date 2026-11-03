<?php

namespace App\Modules\Calendar\Http\Controllers;

use App\Modules\Calendar\Domain\GoogleConnectionService;
use App\Modules\Calendar\Domain\InvalidGoogleState;
use App\Modules\Calendar\Domain\MissingCalendarScope;
use App\Modules\Calendar\Google\GoogleException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Google sends the browser here after the consent screen; the app's web session catches the carli:// redirect.
 */
final class GoogleCallbackController
{
    public const string APP_CALLBACK = 'carli://calendar/google';

    public function __invoke(Request $request, GoogleConnectionService $connections): RedirectResponse
    {
        $state = $request->query('state');
        $code = $request->query('code');

        if ($request->filled('error')) {
            return $this->back(['error' => 'cancelado']);
        }

        if (! is_string($state) || $state === '' || ! is_string($code) || $code === '') {
            return $this->back(['error' => 'estado']);
        }

        try {
            $account = $connections->complete($state, $code);
        } catch (InvalidGoogleState) {
            return $this->back(['error' => 'estado']);
        } catch (MissingCalendarScope) {
            return $this->back(['error' => 'permisos']);
        } catch (GoogleException $exception) {
            Log::warning('Google authorization could not be completed.', ['error' => $exception->getMessage()]);

            return $this->back(['error' => 'google']);
        }

        return $this->back(['account' => $account->id]);
    }

    /**
     * @param  array<string, string>  $query
     */
    private function back(array $query): RedirectResponse
    {
        return redirect()->away(self::APP_CALLBACK.'?'.http_build_query($query));
    }
}
