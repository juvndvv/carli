<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Services\RestockService;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Models\NoteItem;
use App\Modules\Notes\Models\ShoppingProduct;
use Carbon\CarbonImmutable;

final class ShoppingFinish extends Handler
{
    public function __construct(private readonly RestockService $restock) {}

    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, [
            'note_id' => ['required', 'uuid'],
            'item_ids' => ['present', 'array', 'max:2000'],
            'item_ids.*' => ['uuid'],
            'finished_at' => ['required', 'date'],
        ]);

        $note = $this->shoppingNote($user, (string) $data['note_id']);
        $finishedAt = CarbonImmutable::parse((string) $data['finished_at'], 'UTC')->startOfSecond();

        /** @var list<string> $itemIds */
        $itemIds = array_values(array_map('strval', (array) $data['item_ids']));
        $items = NoteItem::query()->where('note_id', $note->id)->whereKey($itemIds)->get();
        $productIds = $items->pluck('product_id')->filter()->unique()->values()->all();

        foreach (ShoppingProduct::query()->ownedBy($user)->whereKey($productIds)->get() as $product) {
            if ($product->last_bought_at === null || $finishedAt->greaterThan($product->last_bought_at)) {
                $product->last_bought_at = $finishedAt;
            }

            $product->times_bought++;
            $product->timestamps = false;
            $product->save();
            $product->timestamps = true;
        }

        NoteItem::query()->whereKey($items->modelKeys())->delete();
        $this->restock->restockNote($note);
    }
}
