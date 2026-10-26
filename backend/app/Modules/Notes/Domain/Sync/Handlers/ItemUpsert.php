<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Services\RestockService;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Models\NoteItem;

final class ItemUpsert extends Handler
{
    public function __construct(private readonly RestockService $restock) {}

    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, [
            'id' => ['required', 'uuid'],
            'note_id' => ['sometimes', 'uuid'],
            'text' => ['sometimes', 'string', 'max:2000'],
            'quantity' => ['sometimes', 'nullable', 'string', 'max:100'],
            'section_id' => ['sometimes', 'nullable', 'uuid'],
            'product_id' => ['sometimes', 'nullable', 'uuid'],
            'checked' => ['sometimes', 'boolean'],
            'position' => ['sometimes', 'integer'],
        ]);

        $item = $this->item($user, (string) $data['id']) ?? new NoteItem;
        $this->requireOnCreate($item, $data, 'note_id', 'El elemento necesita una nota.');
        $this->requireOnCreate($item, $data, 'text', 'El elemento necesita un texto.');
        $this->ensureFresh($item, $operation->at);
        $creating = ! $item->exists;

        if ($creating) {
            $item->id = (string) $data['id'];
        }

        if (array_key_exists('note_id', $data)) {
            $item->note_id = $this->existingNote($user, (string) $data['note_id'])->id;
        }

        if (array_key_exists('section_id', $data)) {
            $item->section_id = $data['section_id'] === null ? null : $this->existingSection($user, (string) $data['section_id'])->id;
        }

        if (array_key_exists('product_id', $data)) {
            $item->product_id = $data['product_id'] === null ? null : $this->existingProduct($user, (string) $data['product_id'])->id;
        }

        if (array_key_exists('checked', $data)) {
            $item->checked_at = filter_var($data['checked'], FILTER_VALIDATE_BOOLEAN) ? $operation->at : null;
        }

        $item->fill(array_intersect_key($data, array_flip(['text', 'quantity', 'position'])));
        $this->persist($item, $operation->at);

        if ($creating) {
            $this->restock->acknowledge($item);
        }
    }
}
