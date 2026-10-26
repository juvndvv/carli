<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Enums\NoteType;
use App\Modules\Notes\Domain\Sync\OperationHandler;
use App\Modules\Notes\Domain\Sync\OperationRejected;
use App\Modules\Notes\Domain\Sync\OperationStale;
use App\Modules\Notes\Models\Folder;
use App\Modules\Notes\Models\Note;
use App\Modules\Notes\Models\NoteItem;
use App\Modules\Notes\Models\ShoppingProduct;
use App\Modules\Notes\Models\ShoppingSection;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Validator;

abstract class Handler implements OperationHandler
{
    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $rules
     * @return array<string, mixed>
     */
    protected function validate(array $payload, array $rules): array
    {
        $validator = Validator::make($payload, $rules);

        if ($validator->fails()) {
            throw new OperationRejected($validator->errors()->first());
        }

        return array_intersect_key($payload, $rules);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    protected function requireOnCreate(Model $model, array $data, string $key, string $message): void
    {
        if (! $model->exists && ! array_key_exists($key, $data)) {
            throw new OperationRejected($message);
        }
    }

    protected function ensureFresh(Model $model, CarbonImmutable $at): void
    {
        $updatedAt = $model->getAttribute('updated_at');

        if ($model->exists && $updatedAt instanceof CarbonImmutable && $updatedAt->greaterThan($at)) {
            throw new OperationStale;
        }
    }

    protected function persist(Model $model, CarbonImmutable $at): void
    {
        if (! $model->exists) {
            $model->setAttribute('created_at', $at);
        }

        $model->setAttribute('updated_at', $at);
        $model->timestamps = false;
        $model->save();
        $model->timestamps = true;
    }

    protected function folder(User $user, string $id): ?Folder
    {
        return $this->ownedOrMissing(Folder::query()->withoutGlobalScope('user')->find($id), $user, 'La carpeta no existe.');
    }

    protected function note(User $user, string $id): ?Note
    {
        return $this->ownedOrMissing(Note::query()->withoutGlobalScope('user')->find($id), $user, 'La nota no existe.');
    }

    protected function item(User $user, string $id): ?NoteItem
    {
        $item = NoteItem::query()->find($id);

        if ($item !== null && $this->note($user, $item->note_id) === null) {
            throw new OperationRejected('El elemento no existe.');
        }

        return $item;
    }

    protected function product(User $user, string $id): ?ShoppingProduct
    {
        return $this->ownedOrMissing(ShoppingProduct::query()->withoutGlobalScope('user')->find($id), $user, 'El producto no existe.');
    }

    protected function section(User $user, string $id): ?ShoppingSection
    {
        return $this->ownedOrMissing(ShoppingSection::query()->withoutGlobalScope('user')->find($id), $user, 'La sección no existe.');
    }

    protected function shoppingNote(User $user, string $id): Note
    {
        $note = $this->note($user, $id);

        if ($note?->type !== NoteType::Shopping) {
            throw new OperationRejected('La lista de la compra no existe.');
        }

        return $note;
    }

    protected function existingFolder(User $user, string $id): Folder
    {
        return $this->folder($user, $id) ?? throw new OperationRejected('La carpeta no existe.');
    }

    protected function existingNote(User $user, string $id): Note
    {
        return $this->note($user, $id) ?? throw new OperationRejected('La nota no existe.');
    }

    protected function existingProduct(User $user, string $id): ShoppingProduct
    {
        return $this->product($user, $id) ?? throw new OperationRejected('El producto no existe.');
    }

    protected function existingSection(User $user, string $id): ShoppingSection
    {
        return $this->section($user, $id) ?? throw new OperationRejected('La sección no existe.');
    }

    /**
     * @template TModel of Model
     *
     * @param  TModel|null  $model
     * @return TModel|null
     */
    private function ownedOrMissing(?Model $model, User $user, string $message): ?Model
    {
        if ($model !== null && $model->getAttribute('user_id') !== $user->id) {
            throw new OperationRejected($message);
        }

        return $model;
    }
}
