<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\ConfirmCurrentPasswordRequest;
use App\Core\Http\Requests\ConfirmTwoFactorRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Laravel\Fortify\Actions\ConfirmTwoFactorAuthentication;
use Laravel\Fortify\Actions\DisableTwoFactorAuthentication;
use Laravel\Fortify\Actions\EnableTwoFactorAuthentication;
use Laravel\Fortify\Actions\GenerateNewRecoveryCodes;
use Laravel\Fortify\Fortify;

class TwoFactorController
{
    public function store(ConfirmCurrentPasswordRequest $request, EnableTwoFactorAuthentication $enable): JsonResponse
    {
        $user = $this->user($request);

        abort_if($user->two_factor_confirmed_at !== null, 409, 'La verificación en dos pasos ya está activada.');

        $enable($user);

        return response()->json([
            'secret_key' => Fortify::currentEncrypter()->decrypt((string) $user->two_factor_secret),
            'qr_code_url' => $user->twoFactorQrCodeUrl(),
            'qr_code_svg' => $user->twoFactorQrCodeSvg(),
        ]);
    }

    public function confirm(ConfirmTwoFactorRequest $request, ConfirmTwoFactorAuthentication $confirm): JsonResponse
    {
        $user = $this->user($request);

        abort_if($user->two_factor_secret === null, 409, 'Primero tienes que activar la verificación en dos pasos.');

        $confirm($user, $request->string('code')->trim()->value());

        return response()->json(['recovery_codes' => $user->recoveryCodes()]);
    }

    public function destroy(ConfirmCurrentPasswordRequest $request, DisableTwoFactorAuthentication $disable): Response
    {
        $disable($this->user($request));

        return response()->noContent();
    }

    public function recoveryCodes(ConfirmCurrentPasswordRequest $request): JsonResponse
    {
        $user = $this->enabledUser($request);

        return response()->json(['recovery_codes' => $user->recoveryCodes()]);
    }

    public function regenerateRecoveryCodes(ConfirmCurrentPasswordRequest $request, GenerateNewRecoveryCodes $generate): JsonResponse
    {
        $user = $this->enabledUser($request);

        $generate($user);

        return response()->json(['recovery_codes' => $user->recoveryCodes()]);
    }

    private function enabledUser(Request $request): User
    {
        $user = $this->user($request);

        abort_if($user->two_factor_confirmed_at === null, 409, 'La verificación en dos pasos no está activada.');

        return $user;
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
