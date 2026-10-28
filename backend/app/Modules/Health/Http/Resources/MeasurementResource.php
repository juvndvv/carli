<?php

namespace App\Modules\Health\Http\Resources;

use App\Modules\Health\Models\Measurement;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Measurement
 */
final class MeasurementResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Measurement $m */
        $m = $this->resource;
        $number = fn (?string $value): ?float => $value === null ? null : (float) $value;

        return [
            'id' => $m->id,
            'measured_at' => $m->measured_at->toIso8601String(),
            'weight_kg' => $m->weight(),
            'source' => $m->source,
            'bmi' => $number($m->bmi),
            'fat_percent' => $number($m->fat_percent),
            'muscle_percent' => $number($m->muscle_percent),
            'water_percent' => $number($m->water_percent),
            'visceral_or_bone' => $m->visceral_or_bone,
            'basal_kcal' => $m->basal_kcal,
            'impedances' => $m->impedances,
            'device' => $m->device,
            'firmware' => $m->firmware,
        ];
    }
}
