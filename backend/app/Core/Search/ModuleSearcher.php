<?php

namespace App\Core\Search;

use App\Models\User;

interface ModuleSearcher
{
    public const string TAG = 'module.searchers';

    public function moduleId(): string;

    /**
     * @return list<SearchResult>
     */
    public function search(User $user, string $query, int $limit): array;
}
