<?php

namespace App\Modules\Notes\Queries;

use App\Modules\Notes\Models\Note;

final readonly class NoteSearchHit
{
    /**
     * @param  list<string>  $folderPath
     */
    public function __construct(
        public Note $note,
        public ?string $snippet,
        public array $folderPath,
    ) {}

    /**
     * @return array{id: string, type: string, title: string|null, snippet: string|null, folder_path: list<string>, archived: bool, updated_at: string|null}
     */
    public function toArray(): array
    {
        return [
            'id' => $this->note->id,
            'type' => $this->note->type->value,
            'title' => $this->note->title,
            'snippet' => $this->snippet,
            'folder_path' => $this->folderPath,
            'archived' => $this->note->archived_at !== null,
            'updated_at' => $this->note->updated_at?->toJSON(),
        ];
    }
}
