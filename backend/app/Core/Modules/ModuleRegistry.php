<?php

namespace App\Core\Modules;

use App\Core\Models\UserModule;
use App\Models\User;
use Illuminate\Support\Collection;
use ReflectionClass;

final class ModuleRegistry
{
    private const array COMING_SOON = [
        ['id' => 'health', 'name' => 'Salud', 'icon' => 'heart-pulse', 'route' => '/salud', 'description' => 'Peso, sueño, actividad y citas médicas.'],
        ['id' => 'habits', 'name' => 'Hábitos', 'icon' => 'repeat', 'route' => '/habitos', 'description' => 'Rachas y seguimiento diario de hábitos.'],
    ];

    /** @var array<string, ModuleManifest>|null */
    private ?array $manifests = null;

    /**
     * @param  list<string>  $providers
     */
    public function __construct(private readonly array $providers) {}

    /**
     * @return array<string, ModuleManifest>
     */
    public function all(): array
    {
        if ($this->manifests !== null) {
            return $this->manifests;
        }

        $manifests = [];

        foreach ($this->providers as $provider) {
            $manifest = $this->loadManifest($provider);

            if ($manifest !== null) {
                $manifests[$manifest->id] = $manifest;
            }
        }

        foreach (self::COMING_SOON as $definition) {
            $manifests[$definition['id']] ??= ModuleManifest::fromArray($definition, available: false);
        }

        return $this->manifests = $manifests;
    }

    /**
     * @return array<string, ModuleManifest>
     */
    public function available(): array
    {
        return array_filter($this->all(), fn (ModuleManifest $manifest) => $manifest->available);
    }

    public function find(string $id): ?ModuleManifest
    {
        return $this->all()[$id] ?? null;
    }

    public function isAvailable(string $id): bool
    {
        return $this->find($id)->available ?? false;
    }

    public function isEnabledFor(User $user, string $id): bool
    {
        if (! $this->isAvailable($id)) {
            return false;
        }

        return $this->userModules($user)->get($id)->enabled ?? true;
    }

    /**
     * @return array<string, mixed>
     */
    public function settingsFor(User $user, string $id): array
    {
        $defaults = $this->find($id)->defaultSettings ?? [];

        return array_replace($defaults, $this->userModules($user)->get($id)->settings ?? []);
    }

    /**
     * @return Collection<string, UserModule>
     */
    public function userModules(User $user): Collection
    {
        return $user->moduleSettings()->get()->keyBy('module_id');
    }

    private function loadManifest(string $provider): ?ModuleManifest
    {
        $path = $this->manifestPath($provider);

        if ($path === null || ! is_file($path)) {
            return null;
        }

        $manifest = require $path;

        return is_array($manifest) ? ModuleManifest::fromArray($manifest) : null;
    }

    private function manifestPath(string $provider): ?string
    {
        if (! class_exists($provider)) {
            return null;
        }

        if (method_exists($provider, 'manifestPath')) {
            $path = $provider::manifestPath();

            return is_string($path) ? $path : null;
        }

        $file = (new ReflectionClass($provider))->getFileName();

        return $file === false ? null : dirname($file).DIRECTORY_SEPARATOR.'module.php';
    }
}
