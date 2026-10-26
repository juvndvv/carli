<?php

namespace App\Modules\Notes\Domain\Services;

use App\Models\User;
use App\Modules\Notes\Domain\Enums\NoteType;
use App\Modules\Notes\Domain\Enums\RestockMode;
use App\Modules\Notes\Domain\Support\DatabaseTime;
use App\Modules\Notes\Domain\Support\DeterministicId;
use App\Modules\Notes\Models\Note;
use App\Modules\Notes\Models\NoteItem;
use App\Modules\Notes\Models\ShoppingProduct;
use App\Modules\Notes\NotesServiceProvider;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;

final class RestockService
{
    public static function isDue(RestockMode $mode, ?int $intervalDays, ?CarbonInterface $lastBoughtAt, CarbonInterface $today): bool
    {
        if ($lastBoughtAt === null) {
            return false;
        }

        return match ($mode) {
            RestockMode::None => false,
            RestockMode::EveryTrip => true,
            RestockMode::Interval => $intervalDays !== null && $intervalDays >= 1
                && self::localDate($lastBoughtAt)->addDays($intervalDays)->lessThanOrEqualTo(self::localDate($today)),
        };
    }

    public static function cycleKey(string $productId, CarbonInterface $lastBoughtAt): string
    {
        return $productId.':'.$lastBoughtAt->getTimestamp();
    }

    public static function itemId(string $cycleKey): string
    {
        return DeterministicId::for($cycleKey);
    }

    public static function today(): CarbonImmutable
    {
        return CarbonImmutable::now(NotesServiceProvider::TIMEZONE);
    }

    public function restockUser(User $user): void
    {
        $this->restock(ShoppingProduct::query()->ownedBy($user));
    }

    public function restockNote(Note $note): void
    {
        $this->restock(ShoppingProduct::query()->ownedBy($note->user_id)->where('note_id', $note->id));
    }

    public function acknowledge(NoteItem $item): void
    {
        if ($item->product_id === null) {
            return;
        }

        $product = ShoppingProduct::query()->withoutGlobalScope('user')->find($item->product_id);

        if ($product?->last_bought_at === null) {
            return;
        }

        $cycleKey = self::cycleKey($product->id, $product->last_bought_at);

        if ($product->restocked_for !== $cycleKey && self::itemId($cycleKey) === $item->id) {
            $this->markRestocked($product, $cycleKey);
        }
    }

    /**
     * @param  Builder<ShoppingProduct>  $products
     */
    private function restock(Builder $products): void
    {
        $today = self::today();

        $candidates = $products
            ->where('restock_mode', '!=', RestockMode::None->value)
            ->whereNotNull('last_bought_at')
            ->whereHas('note', fn (Builder $note) => $note->withoutGlobalScope('user')->where('type', NoteType::Shopping->value)->whereNull('deleted_at'))
            ->get();

        foreach ($candidates as $product) {
            $this->materialize($product, $today);
        }
    }

    private function materialize(ShoppingProduct $product, CarbonImmutable $today): void
    {
        if (! self::isDue($product->restock_mode, $product->restock_interval_days, $product->last_bought_at, $today) || $product->last_bought_at === null) {
            return;
        }

        $cycleKey = self::cycleKey($product->id, $product->last_bought_at);

        if ($product->restocked_for === $cycleKey || NoteItem::query()->where('note_id', $product->note_id)->where('product_id', $product->id)->exists()) {
            return;
        }

        $now = DatabaseTime::format(CarbonImmutable::now());

        $inserted = NoteItem::query()->insertOrIgnore([
            'id' => self::itemId($cycleKey),
            'note_id' => $product->note_id,
            'product_id' => $product->id,
            'text' => $product->name,
            'quantity' => $product->default_quantity,
            'section_id' => $product->section_id,
            'checked_at' => null,
            'position' => ((int) NoteItem::query()->where('note_id', $product->note_id)->max('position')) + 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        if ($inserted > 0) {
            $this->markRestocked($product, $cycleKey);
        }
    }

    private function markRestocked(ShoppingProduct $product, string $cycleKey): void
    {
        $product->restocked_for = $cycleKey;
        $product->timestamps = false;
        $product->save();
        $product->timestamps = true;
    }

    private static function localDate(CarbonInterface $moment): CarbonImmutable
    {
        return CarbonImmutable::createFromFormat('!Y-m-d', $moment->copy()->setTimezone(NotesServiceProvider::TIMEZONE)->format('Y-m-d'), 'UTC')
            ?: throw new \LogicException('Invalid date.');
    }
}
