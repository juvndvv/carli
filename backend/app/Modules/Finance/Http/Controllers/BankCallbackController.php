<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\BankSync\Data\BankReturnTarget;
use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use App\Modules\Finance\BankSync\Exceptions\InvalidBankState;
use App\Modules\Finance\BankSync\Services\BankConnectionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

final class BankCallbackController
{
    public const string SETTINGS_PATH = '/finanzas/ajustes/bancos';

    public const string APP_CALLBACK = 'carli://bank/callback';

    public function __invoke(Request $request, BankConnectionService $connections): RedirectResponse
    {
        $state = $request->query('state');
        $code = $request->query('code');

        $target = $connections->returnTargetOf($state);

        if ($request->filled('error')) {
            return $this->failed($target, 'cancelado');
        }

        if (! is_string($state) || $state === '' || ! is_string($code) || $code === '') {
            return $this->failed($target, 'estado');
        }

        try {
            $result = $connections->complete($state, $code);
        } catch (InvalidBankState) {
            return $this->failed($target, 'estado');
        } catch (BankProviderException $exception) {
            Log::warning('Bank authorization could not be completed.', ['error' => $exception->getMessage()]);

            return $this->failed($target, 'proveedor');
        }

        $connectionId = $result['connection']->id;

        if ($result['return_to'] === BankReturnTarget::App) {
            $query = ['connection' => $connectionId] + ($result['renewed'] ? ['renovado' => '1'] : []);

            return redirect()->away(self::APP_CALLBACK.'?'.http_build_query($query));
        }

        $path = self::SETTINGS_PATH.'/'.$connectionId.'/vincular';

        return redirect()->to($result['renewed'] ? $path.'?renovado=1' : $path);
    }

    private function failed(BankReturnTarget $target, string $reason): RedirectResponse
    {
        return $target === BankReturnTarget::App
            ? redirect()->away(self::APP_CALLBACK.'?error='.$reason)
            : redirect()->to(self::SETTINGS_PATH.'?error='.$reason);
    }
}
