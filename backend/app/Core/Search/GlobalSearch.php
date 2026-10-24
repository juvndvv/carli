<?php

namespace App\Core\Search;

use App\Core\Modules\ModuleRegistry;
use App\Models\User;
use Illuminate\Contracts\Container\Container;

final readonly class GlobalSearch
{
    public function __construct(
        private Container $container,
        private ModuleRegistry $modules,
    ) {}

    /**
     * @return list<array{module: string, module_name: string, type: string, id: string, title: string, subtitle: string|null, url: string, icon: string|null}>
     */
    public function search(User $user, string $query, int $limitPerModule): array
    {
        $results = [];

        foreach ($this->container->tagged(ModuleSearcher::TAG) as $searcher) {
            if (! $searcher instanceof ModuleSearcher || ! $this->modules->isEnabledFor($user, $searcher->moduleId())) {
                continue;
            }

            $moduleName = $this->modules->find($searcher->moduleId())->name ?? $searcher->moduleId();

            foreach (array_slice($searcher->search($user, $query, $limitPerModule), 0, $limitPerModule) as $result) {
                $results[] = [
                    'module' => $searcher->moduleId(),
                    'module_name' => $moduleName,
                    'type' => $result->type,
                    'id' => $result->id,
                    'title' => $result->title,
                    'subtitle' => $result->subtitle,
                    'url' => $result->url,
                    'icon' => $result->icon,
                ];
            }
        }

        return $results;
    }
}
