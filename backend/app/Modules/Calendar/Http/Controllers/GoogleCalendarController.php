<?php

namespace App\Modules\Calendar\Http\Controllers;

use App\Modules\Calendar\Domain\GoogleSync;
use App\Modules\Calendar\Google\GoogleException;
use App\Modules\Calendar\Http\Requests\UpdateGoogleCalendarRequest;
use App\Modules\Calendar\Models\GoogleCalendar;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

final class GoogleCalendarController
{
    public function update(UpdateGoogleCalendarRequest $request, GoogleCalendar $calendar, GoogleSync $sync): JsonResponse
    {
        abort_unless($calendar->user_id === $request->user()?->getAuthIdentifier(), 404);

        $calendar->selected = $request->boolean('selected');
        $calendar->save();

        try {
            $sync->calendar($calendar);
        } catch (GoogleException $exception) {
            // The scheduled sync copies it later.
            Log::warning('Google calendar copy after toggling failed.', ['calendar' => $calendar->id, 'error' => $exception->getMessage()]);
        }

        return response()->json(['data' => self::calendar($calendar)]);
    }

    /**
     * @return array<string, mixed>
     */
    public static function calendar(GoogleCalendar $calendar): array
    {
        return [
            'id' => $calendar->id,
            'name' => $calendar->name,
            'color' => $calendar->color,
            'primary' => $calendar->primary,
            'selected' => $calendar->selected,
        ];
    }
}
