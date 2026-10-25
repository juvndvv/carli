<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use App\Modules\Finance\BankSync\Exceptions\InvalidBankState;
use App\Modules\Finance\BankSync\Services\BankConnectionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

final class BankCallbackController
{
    public const string SETTINGS_PATH = '/finanzas/ajustes/bancos';

    public function __invoke(Request $request, BankConnectionService $connections): RedirectResponse
    {
        $state = $request->query('state');
        $code = $request->query('code');

        if ($request->filled('error')) {
            return $this->failed('cancelado');
        }

        if (! is_string($state) || $state === '' || ! is_string($code) || $code === '') {
            return $this->failed('estado');
        }

        try {
            $result = $connections->complete($state, $code);
        } catch (InvalidBankState) {
            return $this->failed('estado');
        } catch (BankProviderException $exception) {
            Log::warning('Bank authorization could not be completed.', ['error' => $exception->getMessage()]);

            return $this->failed('proveedor');
        }

        $path = self::SETTINGS_PATH.'/'.$result['connection']->id.'/vincular';

        return redirect()->to($result['renewed'] ? $path.'?renovado=1' : $path);
    }

    private function failed(string $reason): RedirectResponse
    {
        return redirect()->to(self::SETTINGS_PATH.'?error='.$reason);
    }
}
