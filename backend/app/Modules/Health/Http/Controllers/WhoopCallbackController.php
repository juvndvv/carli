<?php

namespace App\Modules\Health\Http\Controllers;

use App\Modules\Health\Domain\InvalidWhoopState;
use App\Modules\Health\Domain\WhoopAlreadyLinked;
use App\Modules\Health\Domain\WhoopConnectionService;
use App\Modules\Health\Whoop\WhoopException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * WHOOP sends the browser here after the consent screen; the app's web session catches the carli:// redirect.
 */
final class WhoopCallbackController
{
    public const string APP_CALLBACK = 'carli://health/whoop';

    public function __invoke(Request $request, WhoopConnectionService $connections): RedirectResponse
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
            $connections->complete($state, $code);
        } catch (InvalidWhoopState) {
            return $this->back(['error' => 'estado']);
        } catch (WhoopAlreadyLinked) {
            return $this->back(['error' => 'otra']);
        } catch (WhoopException $exception) {
            Log::warning('WHOOP authorization could not be completed.', ['error' => $exception->getMessage()]);

            return $this->back(['error' => 'whoop']);
        }

        return $this->back(['ok' => '1']);
    }

    /**
     * @param  array<string, string>  $query
     */
    private function back(array $query): RedirectResponse
    {
        return redirect()->away(self::APP_CALLBACK.'?'.http_build_query($query));
    }
}
