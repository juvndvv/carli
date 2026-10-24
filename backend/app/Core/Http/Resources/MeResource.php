<?php

namespace App\Core\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class MeResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'two_factor_enabled' => $this->two_factor_confirmed_at !== null,
            'two_factor_pending' => $this->two_factor_secret !== null && $this->two_factor_confirmed_at === null,
            'preferences' => $this->resolvedPreferences(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
