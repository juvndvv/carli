<?php

namespace Tests\Feature\Core\Fixtures\Journal;

use App\Core\Search\ModuleSearcher;
use App\Core\Search\SearchResult;
use App\Models\User;

class JournalSearcher implements ModuleSearcher
{
    public function moduleId(): string
    {
        return 'journal';
    }

    public function search(User $user, string $query, int $limit): array
    {
        return array_map(
            fn (int $index) => new SearchResult('entry', "entry-{$index}", "Entrada {$index}: {$query}", "/diario/{$index}", 'Hoy', 'book'),
            range(1, 10),
        );
    }
}
