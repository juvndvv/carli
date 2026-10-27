<?php

namespace App\Core\Pending;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use Illuminate\Contracts\Container\Container;

final class PendingRegistry
{
    /** @var array<string, class-string<PendingItemsProvider>|PendingItemsProvider> */
    private array $registered = [];

    /** @var array<string, class-string<DigestLineProvider>|DigestLineProvider> */
    private array $lineProviders = [];

    public function __construct(private readonly Container $container) {}

    /**
     * @param  class-string<PendingItemsProvider>|PendingItemsProvider  $provider
     */
    public function register(string|PendingItemsProvider $provider): void
    {
        $key = is_string($provider) ? $provider : $provider::class;

        $this->registered[$key] = $provider;
    }

    /**
     * @param  class-string<DigestLineProvider>|DigestLineProvider  $provider
     */
    public function registerDigestLines(string|DigestLineProvider $provider): void
    {
        $key = is_string($provider) ? $provider : $provider::class;

        $this->lineProviders[$key] = $provider;
    }

    /**
     * @return list<string>
     */
    public function digestLines(User $user): array
    {
        $modules = $this->container->make(ModuleRegistry::class);
        $lines = [];

        foreach ($this->lineProviders as $provider) {
            $instance = is_string($provider) ? $this->container->make($provider) : $provider;

            if ($modules->isEnabledFor($user, $instance->moduleId())) {
                array_push($lines, ...$instance->digestLines($user));
            }
        }

        return $lines;
    }

    /**
     * @return array<string, PendingItemsProvider>
     */
    public function providersFor(User $user): array
    {
        $modules = $this->container->make(ModuleRegistry::class);
        $providers = [];

        foreach ($this->registered as $provider) {
            $instance = is_string($provider) ? $this->container->make($provider) : $provider;

            if ($modules->isEnabledFor($user, $instance->moduleId())) {
                $providers[$instance->moduleId()] ??= $instance;
            }
        }

        return $providers;
    }

    public function hasProvidersFor(User $user): bool
    {
        return $this->providersFor($user) !== [];
    }

    /**
     * @return array{total: int, by_module: list<array{module: string, module_name: string, type: string, count: int}>}
     */
    public function summary(User $user): array
    {
        $modules = $this->container->make(ModuleRegistry::class);
        $total = 0;
        $byModule = [];

        foreach ($this->providersFor($user) as $moduleId => $provider) {
            $moduleName = $modules->find($moduleId)->name ?? $moduleId;

            foreach ($provider->counts($user) as $type => $count) {
                if ($count <= 0) {
                    continue;
                }

                $total += $count;
                $byModule[] = ['module' => $moduleId, 'module_name' => $moduleName, 'type' => (string) $type, 'count' => $count];
            }
        }

        return ['total' => $total, 'by_module' => $byModule];
    }

    public function page(User $user, ?string $module, ?string $type, ?string $cursor): PendingPage
    {
        $providers = $this->providersFor($user);

        if ($module !== null) {
            $providers = array_intersect_key($providers, [$module => true]);
        }

        $segments = array_map(
            fn (PendingItemsProvider $provider) => fn (?string $inner): PendingPage => $provider->items($user, $type, $inner),
            $providers,
        );

        return PendingPage::chain($segments, $cursor);
    }

    /**
     * @return list<string>
     */
    public function describe(User $user): array
    {
        $phrases = [];

        foreach ($this->providersFor($user) as $provider) {
            foreach ($provider->counts($user) as $type => $count) {
                if ($count > 0) {
                    $phrases[] = $provider->describe((string) $type, $count);
                }
            }
        }

        return $phrases;
    }

    /**
     * @return array{total: int, phrases: list<string>, lines: list<string>}
     */
    public function digest(User $user): array
    {
        $total = $this->summary($user)['total'];
        $phrases = $this->describe($user);

        foreach ($this->providersFor($user) as $provider) {
            if (! $provider instanceof DailyDigestContributor) {
                continue;
            }

            foreach ($provider->digestCounts($user) as $type => $count) {
                if ($count > 0) {
                    $total += $count;
                    $phrases[] = $provider->describe((string) $type, $count);
                }
            }
        }

        return ['total' => $total, 'phrases' => $phrases, 'lines' => $this->digestLines($user)];
    }
}
