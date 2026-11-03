<?php

namespace App\Modules\Health\Http\Resources;

use App\Modules\Health\Models\BodyMeasurement;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin BodyMeasurement
 */
final class BodyMeasurementResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var BodyMeasurement $m */
        $m = $this->resource;

        return [
            'id' => $m->id,
            'site_id' => $m->site_id,
            'measured_at' => $m->measured_at->toIso8601String(),
            'value_cm' => $m->value(),
        ];
    }
}
