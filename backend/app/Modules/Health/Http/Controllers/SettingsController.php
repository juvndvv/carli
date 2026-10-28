<?php

namespace App\Modules\Health\Http\Controllers;

use App\Modules\Health\Domain\HealthSettings;
use App\Modules\Health\Http\Requests\SettingsRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class SettingsController extends HealthController
{
    public function __construct(private readonly HealthSettings $settings) {}

    public function show(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->settings->for($this->user($request))]);
    }

    public function update(SettingsRequest $request): JsonResponse
    {
        $user = $this->user($request);
        $changes = $request->validated();

        if (isset($changes['reminder_days']) && is_array($changes['reminder_days'])) {
            $days = array_values(array_unique(array_map('intval', $changes['reminder_days'])));
            sort($days);
            $changes['reminder_days'] = $days;
        }

        $this->settings->update($user, $changes);

        return response()->json(['data' => $this->settings->for($user)]);
    }
}
