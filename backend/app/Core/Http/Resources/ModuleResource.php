<?php

namespace App\Core\Http\Resources;

use App\Core\Modules\ModuleManifest;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @property-read array{manifest: ModuleManifest, enabled: bool, settings: array<string, mixed>} $resource
 */
class ModuleResource extends JsonResource
{
    /**
     * @param  array{manifest: ModuleManifest, enabled: bool, settings: array<string, mixed>}  $resource
     */
    public function __construct(array $resource)
    {
        parent::__construct($resource);
    }

    /**
     * @return array{id: string, name: string, icon: string, route: string, description: string|null, available: bool, coming_soon: bool, enabled: bool, settings: array<string, mixed>|object}
     */
    public function toArray(Request $request): array
    {
        $manifest = $this->resource['manifest'];

        return [
            'id' => $manifest->id,
            'name' => $manifest->name,
            'icon' => $manifest->icon,
            'route' => $manifest->route,
            'description' => $manifest->description,
            'available' => $manifest->available,
            'coming_soon' => ! $manifest->available,
            'enabled' => $this->resource['enabled'],
            'settings' => $this->resource['settings'] === [] ? (object) [] : $this->resource['settings'],
        ];
    }
}
