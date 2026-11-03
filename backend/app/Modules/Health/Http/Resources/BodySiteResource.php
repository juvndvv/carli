<?php

namespace App\Modules\Health\Http\Resources;

use App\Modules\Health\Models\BodySite;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin BodySite
 */
final class BodySiteResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var BodySite $site */
        $site = $this->resource;

        return [
            'id' => $site->id,
            'name' => $site->name,
            'zone' => $site->zone,
            'side' => $site->side,
            'position' => $site->position,
            'archived' => $site->archived_at !== null,
        ];
    }
}
