<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\DeletePushDeviceRequest;
use App\Core\Http\Requests\StorePushDeviceRequest;
use App\Core\Models\PushDevice;
use App\Core\Push\ApnsConfiguration;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class PushDeviceController
{
    public function store(StorePushDeviceRequest $request): JsonResponse
    {
        $device = PushDevice::query()->updateOrCreate(
            ['token' => strtolower((string) $request->validated('token'))],
            ['user_id' => $this->user($request)->id, 'environment' => $request->validated('environment')],
        );

        return response()->json([
            'data' => [
                'id' => $device->id,
                'environment' => $device->environment->value,
            ],
            'push_configured' => ApnsConfiguration::isConfigured(),
        ], 201);
    }

    public function destroy(DeletePushDeviceRequest $request): Response
    {
        $this->user($request)->pushDevices()
            ->where('token', strtolower((string) $request->validated('token')))
            ->delete();

        return response()->noContent();
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
