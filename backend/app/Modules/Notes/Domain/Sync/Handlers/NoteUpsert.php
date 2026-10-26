<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Enums\CheckedBehavior;
use App\Modules\Notes\Domain\Enums\NoteType;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Domain\Sync\OperationRejected;
use App\Modules\Notes\Models\Note;
use Carbon\CarbonImmutable;
use Illuminate\Validation\Rule;

final class NoteUpsert extends Handler
{
    private const array FLAGS = ['pinned' => 'pinned_at', 'archived' => 'archived_at', 'deleted' => 'deleted_at'];

    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, [
            'id' => ['required', 'uuid'],
            'type' => ['sometimes', 'string', Rule::in(NoteType::values())],
            'folder_id' => ['sometimes', 'nullable', 'uuid'],
            'title' => ['sometimes', 'nullable', 'string', 'max:500'],
            'body' => ['sometimes', 'nullable', 'string', 'max:200000'],
            'pinned' => ['sometimes', 'boolean'],
            'archived' => ['sometimes', 'boolean'],
            'deleted' => ['sometimes', 'boolean'],
            'checked_behavior' => ['sometimes', 'string', Rule::in(CheckedBehavior::values())],
            'is_primary' => ['sometimes', 'boolean'],
            'sort' => ['sometimes', 'integer'],
        ]);

        $note = $this->note($user, (string) $data['id']) ?? new Note;
        $this->requireOnCreate($note, $data, 'type', 'La nota necesita un tipo.');
        $this->ensureFresh($note, $operation->at);

        if (! $note->exists) {
            $note->id = (string) $data['id'];
            $note->user_id = $user->id;
        }

        if (array_key_exists('type', $data)) {
            $type = NoteType::from((string) $data['type']);

            if ($note->exists && ! $note->type->canBecome($type)) {
                throw new OperationRejected('Una lista de la compra no puede cambiar de tipo.');
            }

            $note->type = $type;
        }

        if (array_key_exists('folder_id', $data)) {
            $note->folder_id = $data['folder_id'] === null ? null : $this->existingFolder($user, (string) $data['folder_id'])->id;
        }

        if (array_key_exists('checked_behavior', $data)) {
            $note->checked_behavior = CheckedBehavior::from((string) $data['checked_behavior']);
        }

        $note->fill(array_intersect_key($data, array_flip(['title', 'body', 'sort'])));
        $this->applyFlags($note, $data, $operation->at);
        $this->applyPrimary($user, $note, $data);
        $this->persist($note, $operation->at);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function applyFlags(Note $note, array $data, CarbonImmutable $at): void
    {
        foreach (self::FLAGS as $flag => $column) {
            if (array_key_exists($flag, $data)) {
                $note->setAttribute($column, filter_var($data[$flag], FILTER_VALIDATE_BOOLEAN) ? ($note->getAttribute($column) ?? $at) : null);
            }
        }
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function applyPrimary(User $user, Note $note, array $data): void
    {
        $wantsPrimary = array_key_exists('is_primary', $data)
            ? filter_var($data['is_primary'], FILTER_VALIDATE_BOOLEAN)
            : ($note->exists ? $note->is_primary && $note->type === NoteType::Shopping : null);

        if ($wantsPrimary === null) {
            $wantsPrimary = $note->type === NoteType::Shopping
                && ! Note::query()->ownedBy($user)->where('is_primary', true)->exists();
        }

        if ($wantsPrimary && $note->type !== NoteType::Shopping) {
            throw new OperationRejected('Solo una lista de la compra puede ser la principal.');
        }

        if ($wantsPrimary) {
            Note::query()->ownedBy($user)->where('is_primary', true)->whereKeyNot($note->id)->toBase()->update(['is_primary' => false]);
        }

        $note->is_primary = $wantsPrimary;
    }
}
