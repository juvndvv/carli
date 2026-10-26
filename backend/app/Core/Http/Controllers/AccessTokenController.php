<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\IssueAccessTokenRequest;
use App\Core\Http\Resources\MeResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Laravel\Fortify\Contracts\TwoFactorAuthenticationProvider;
use Laravel\Sanctum\PersonalAccessToken;

class AccessTokenController
{
    public function __construct(private readonly TwoFactorAuthenticationProvider $twoFactor) {}

    public function store(IssueAccessTokenRequest $request): JsonResponse
    {
        $user = User::query()->where('email', $request->string('email')->value())->first();

        if ($user === null || ! Hash::check($request->string('password')->value(), $user->password)) {
            throw ValidationException::withMessages(['email' => __('auth.failed')]);
        }

        if ($user->hasEnabledTwoFactorAuthentication() && ! $this->passesTwoFactor($user, $request)) {
            return response()->json(['two_factor' => true]);
        }

        $token = $user->createToken($request->string('device_name')->value());

        return response()->json([
            'token' => $token->plainTextToken,
            'user' => new MeResource($user),
        ], 201);
    }

    public function destroy(Request $request): Response
    {
        $bearer = $request->bearerToken();

        if ($bearer !== null) {
            PersonalAccessToken::findToken($bearer)?->delete();
        }

        return response()->noContent();
    }

    private function passesTwoFactor(User $user, IssueAccessTokenRequest $request): bool
    {
        $code = $request->string('code')->value();
        $recoveryCode = $request->string('recovery_code')->value();

        if ($code === '' && $recoveryCode === '') {
            return false;
        }

        if ($code !== '') {
            if (! $this->twoFactor->verify((string) decrypt((string) $user->two_factor_secret), $code)) {
                throw ValidationException::withMessages(['code' => __('The provided two factor authentication code was invalid.')]);
            }

            return true;
        }

        if (! in_array($recoveryCode, $user->recoveryCodes(), true)) {
            throw ValidationException::withMessages(['recovery_code' => __('The provided two factor recovery code was invalid.')]);
        }

        $user->replaceRecoveryCode($recoveryCode);

        return true;
    }
}
