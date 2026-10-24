<?php

namespace App\Core\Http\Controllers;

use App\Core\Http\Requests\UpdateModuleRequest;
use App\Core\Http\Resources\ModuleResource;
use App\Core\Models\UserModule;
use App\Core\Modules\ModuleManifest;
use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ModuleController
{
    public function __construct(private readonly ModuleRegistry $modules) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $this->user($request);

        $items = array_map(
            fn (ModuleManifest $manifest) => $this->present($user, $manifest),
            array_values($this->modules->all()),
        );

        return ModuleResource::collection($items);
    }

    public function update(UpdateModuleRequest $request, string $module): ModuleResource
    {
        $manifest = $this->modules->find($module);

        abort_if($manifest === null, 404, 'El módulo no existe.');
        abort_unless($manifest->available, 422, 'El módulo todavía no está disponible.');

        $user = $this->user($request);

        $record = UserModule::query()->firstOrNew(['user_id' => $user->id, 'module_id' => $manifest->id]);

        if ($request->has('enabled')) {
            $record->enabled = $request->boolean('enabled');
        }

        if ($request->has('settings')) {
            $record->settings = array_replace($record->settings ?? [], (array) $request->validated('settings'));
        }

        $record->save();

        return new ModuleResource($this->present($user, $manifest));
    }

    /**
     * @return array{manifest: ModuleManifest, enabled: bool, settings: array<string, mixed>}
     */
    private function present(User $user, ModuleManifest $manifest): array
    {
        return [
            'manifest' => $manifest,
            'enabled' => $this->modules->isEnabledFor($user, $manifest->id),
            'settings' => $manifest->available ? $this->modules->settingsFor($user, $manifest->id) : [],
        ];
    }

    private function user(Request $request): User
    {
        /** @var User */
        return $request->user();
    }
}
