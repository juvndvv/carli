<?php

namespace App\Modules\Notes\Search;

use App\Core\Search\ModuleSearcher;
use App\Core\Search\SearchResult;
use App\Models\User;
use App\Modules\Notes\Queries\NoteSearch;
use App\Modules\Notes\Queries\NoteSearchHit;
use Illuminate\Support\Str;

final readonly class NotesSearcher implements ModuleSearcher
{
    public function __construct(private NoteSearch $notes) {}

    public function moduleId(): string
    {
        return 'notes';
    }

    public function search(User $user, string $query, int $limit): array
    {
        return array_map(fn (NoteSearchHit $hit) => new SearchResult(
            type: 'note',
            id: $hit->note->id,
            title: $this->title($hit),
            url: '/notas/n/'.$hit->note->id,
            subtitle: $hit->folderPath === [] ? $hit->note->type->label() : implode(' › ', $hit->folderPath),
            icon: $hit->note->type->icon(),
        ), $this->notes->search($user, $query, $limit));
    }

    private function title(NoteSearchHit $hit): string
    {
        $title = trim((string) $hit->note->title);

        if ($title !== '') {
            return $title;
        }

        $snippet = trim((string) $hit->snippet);

        return $snippet === '' ? 'Sin título' : Str::limit($snippet, 80);
    }
}
