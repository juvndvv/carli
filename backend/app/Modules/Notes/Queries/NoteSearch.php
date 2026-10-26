<?php

namespace App\Modules\Notes\Queries;

use App\Models\User;
use App\Modules\Notes\Domain\Enums\NoteType;
use App\Modules\Notes\Domain\Support\TextNormalizer;
use App\Modules\Notes\Models\Note;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class NoteSearch
{
    public const int SNIPPET_LENGTH = 120;

    /**
     * @return list<NoteSearchHit>
     */
    public function search(User $user, string $query, int $limit = 30): array
    {
        $words = $this->words($query);

        if ($words === []) {
            return [];
        }

        $tsQuery = implode(' & ', array_map(fn (string $word) => $word.':*', $words));
        $like = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], TextNormalizer::normalize($query)).'%';

        $rows = DB::select(<<<'SQL'
            SELECT n.id,
                greatest(
                    ts_rank(n.search, q.query),
                    coalesce((SELECT max(ts_rank(i.search, q.query)) FROM notes.note_items i WHERE i.note_id = n.id AND i.search @@ q.query), 0)
                ) AS rank,
                (SELECT string_agg(i.text, ', ' ORDER BY i.position, i.created_at)
                    FROM notes.note_items i
                    WHERE i.note_id = n.id AND (i.search @@ q.query OR notes.immutable_unaccent(lower(i.text)) ILIKE :item_like)) AS item_matches
            FROM notes.notes n
            CROSS JOIN (SELECT to_tsquery('spanish', notes.immutable_unaccent(:tsquery)) AS query) q
            WHERE n.user_id = :user_id
                AND n.deleted_at IS NULL
                AND (
                    n.search @@ q.query
                    OR EXISTS (SELECT 1 FROM notes.note_items i WHERE i.note_id = n.id AND i.search @@ q.query)
                    OR notes.immutable_unaccent(lower(coalesce(n.title, '') || ' ' || coalesce(n.body, ''))) ILIKE :note_like
                )
            ORDER BY (n.pinned_at IS NOT NULL) DESC, rank DESC, n.updated_at DESC
            LIMIT :limit
            SQL, [
            'item_like' => $like,
            'tsquery' => $tsQuery,
            'user_id' => $user->id,
            'note_like' => $like,
            'limit' => $limit,
        ]);

        if ($rows === []) {
            return [];
        }

        /** @var array<string, string|null> $itemMatches */
        $itemMatches = [];
        foreach ($rows as $row) {
            $itemMatches[(string) $row->id] = $row->item_matches === null ? null : (string) $row->item_matches;
        }

        $notes = Note::query()->ownedBy($user)->whereKey(array_keys($itemMatches))->get()->keyBy('id');
        $paths = $this->folderPaths($notes->pluck('folder_id')->filter()->unique()->values()->all());

        $hits = [];
        foreach ($itemMatches as $id => $items) {
            $note = $notes->get($id);

            if ($note instanceof Note) {
                $hits[] = new NoteSearchHit($note, $this->snippet($note, $items, $words), $note->folder_id === null ? [] : ($paths[$note->folder_id] ?? []));
            }
        }

        return $hits;
    }

    /**
     * @return list<string>
     */
    private function words(string $query): array
    {
        $clean = (string) preg_replace('/[^\p{L}\p{N}]+/u', ' ', TextNormalizer::normalize($query));

        return array_values(array_filter(explode(' ', $clean), fn (string $word) => $word !== ''));
    }

    /**
     * @param  list<string>  $words
     */
    private function snippet(Note $note, ?string $items, array $words): ?string
    {
        if ($note->type !== NoteType::Text && $items !== null) {
            return $items;
        }

        $body = trim((string) $note->body);

        if ($body === '') {
            return $items;
        }

        foreach (preg_split('/\R/u', $body) ?: [] as $line) {
            $normalized = TextNormalizer::normalize($line);

            foreach ($words as $word) {
                if (str_contains($normalized, $word)) {
                    return Str::limit(trim($line), self::SNIPPET_LENGTH * 2);
                }
            }
        }

        return Str::limit($body, self::SNIPPET_LENGTH, '');
    }

    /**
     * @param  array<int, mixed>  $folderIds
     * @return array<string, list<string>>
     */
    private function folderPaths(array $folderIds): array
    {
        if ($folderIds === []) {
            return [];
        }

        $rows = DB::select(<<<'SQL'
            WITH RECURSIVE path AS (
                SELECT f.id AS start_id, f.parent_id, f.name, 0 AS depth
                FROM notes.note_folders f
                WHERE f.id = ANY (CAST(:ids AS uuid[]))
                UNION ALL
                SELECT path.start_id, parent.parent_id, parent.name, path.depth + 1
                FROM path
                JOIN notes.note_folders parent ON parent.id = path.parent_id
                WHERE path.depth < 64
            )
            SELECT start_id, json_agg(name ORDER BY depth DESC) AS names
            FROM path
            GROUP BY start_id
            SQL, ['ids' => '{'.implode(',', array_map('strval', $folderIds)).'}']);

        $paths = [];
        foreach ($rows as $row) {
            $names = json_decode((string) $row->names, true);
            $paths[(string) $row->start_id] = is_array($names) ? array_values(array_map('strval', $names)) : [];
        }

        return $paths;
    }
}
