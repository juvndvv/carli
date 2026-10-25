<?php

namespace Tests\Feature\Core\Fixtures\Journal;

use App\Core\Pending\PendingItem;
use App\Core\Pending\PendingItemsProvider;
use App\Core\Pending\PendingPage;
use App\Models\User;

class JournalPendingItems implements PendingItemsProvider
{
    private const int PAGE_SIZE = 2;

    /**
     * @param  array<string, int>  $counts
     */
    public function __construct(public array $counts = ['entry_to_review' => 3, 'draft' => 1]) {}

    public function moduleId(): string
    {
        return 'journal';
    }

    public function counts(User $user): array
    {
        return $this->counts;
    }

    public function items(User $user, ?string $type, ?string $cursor): PendingPage
    {
        $segments = [];

        foreach ($this->counts as $each => $count) {
            if ($type === null || $type === $each) {
                $segments[$each] = fn (?string $inner) => $this->page($each, $count, (int) ($inner ?? 0));
            }
        }

        return PendingPage::chain($segments, $cursor);
    }

    public function describe(string $type, int $count): string
    {
        return $type === 'draft' ? "{$count} borrador sin terminar" : "{$count} entradas por revisar";
    }

    private function page(string $type, int $count, int $offset): PendingPage
    {
        $items = [];

        for ($index = $offset; $index < min($count, $offset + self::PAGE_SIZE); $index++) {
            $items[] = new PendingItem('journal', $type, "{$type}-{$index}", "Entrada {$index}", '2026-10-25', "/diario/{$index}");
        }

        return new PendingPage($items, $offset + self::PAGE_SIZE < $count ? (string) ($offset + self::PAGE_SIZE) : null);
    }
}
