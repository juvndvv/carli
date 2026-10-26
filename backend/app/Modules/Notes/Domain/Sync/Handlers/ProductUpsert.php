<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Enums\RestockMode;
use App\Modules\Notes\Domain\Support\TextNormalizer;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Domain\Sync\OperationRejected;
use App\Modules\Notes\Models\ShoppingProduct;
use Carbon\CarbonImmutable;
use Illuminate\Validation\Rule;

final class ProductUpsert extends Handler
{
    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, [
            'id' => ['required', 'uuid'],
            'note_id' => ['sometimes', 'uuid'],
            'name' => ['sometimes', 'string', 'filled', 'max:255'],
            'section_id' => ['sometimes', 'nullable', 'uuid'],
            'default_quantity' => ['sometimes', 'nullable', 'string', 'max:100'],
            'restock_mode' => ['sometimes', 'string', Rule::in(RestockMode::values())],
            'restock_interval_days' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:3650'],
            'last_bought_at' => ['sometimes', 'nullable', 'date'],
            'times_bought' => ['sometimes', 'integer', 'min:0'],
            'restocked_for' => ['sometimes', 'nullable', 'string', 'max:100'],
        ]);

        $product = $this->product($user, (string) $data['id']) ?? new ShoppingProduct;
        $this->requireOnCreate($product, $data, 'note_id', 'El producto necesita una lista de la compra.');
        $this->requireOnCreate($product, $data, 'name', 'El producto necesita un nombre.');
        $this->ensureFresh($product, $operation->at);

        if (! $product->exists) {
            $product->id = (string) $data['id'];
            $product->user_id = $user->id;
            $product->restock_mode = RestockMode::None;
            $product->times_bought = 0;
        }

        if (array_key_exists('note_id', $data)) {
            $product->note_id = $this->shoppingNote($user, (string) $data['note_id'])->id;
        }

        if (array_key_exists('section_id', $data)) {
            $product->section_id = $data['section_id'] === null ? null : $this->existingSection($user, (string) $data['section_id'])->id;
        }

        if (array_key_exists('restock_mode', $data)) {
            $product->restock_mode = RestockMode::from((string) $data['restock_mode']);
        }

        if (array_key_exists('last_bought_at', $data)) {
            $product->last_bought_at = $data['last_bought_at'] === null
                ? null
                : CarbonImmutable::parse((string) $data['last_bought_at'], 'UTC')->startOfSecond();
        }

        $product->fill(array_intersect_key($data, array_flip(['name', 'default_quantity', 'restock_interval_days', 'times_bought', 'restocked_for'])));
        $product->name = trim($product->name);

        if ($product->name === '') {
            throw new OperationRejected('El producto necesita un nombre.');
        }

        $product->name_normalized = TextNormalizer::normalize($product->name);

        if ($product->restock_mode === RestockMode::Interval && $product->restock_interval_days === null) {
            throw new OperationRejected('Indica cada cuántos días se repone el producto.');
        }

        $this->persist($product, $operation->at);
    }
}
