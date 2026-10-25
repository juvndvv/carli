<?php

namespace App\Core\Pending;

use Closure;

final readonly class PendingPage
{
    /**
     * @param  list<PendingItem>  $items
     */
    public function __construct(
        public array $items,
        public ?string $nextCursor = null,
    ) {}

    public static function empty(): self
    {
        return new self([]);
    }

    /**
     * @param  array<string, Closure(?string): PendingPage>  $segments
     */
    public static function chain(array $segments, ?string $cursor): self
    {
        $keys = array_map('strval', array_keys($segments));
        $position = PendingCursor::decode($cursor);
        $index = $position === null ? 0 : array_search($position['segment'], $keys, true);

        if ($index === false || ($position === null && $cursor !== null && $cursor !== '')) {
            return self::empty();
        }

        $inner = $position['inner'] ?? null;

        for ($count = count($keys); $index < $count; $index++) {
            $page = $segments[$keys[$index]]($inner);
            $inner = null;

            $next = match (true) {
                $page->nextCursor !== null => PendingCursor::encode($keys[$index], $page->nextCursor),
                $index + 1 < $count => PendingCursor::encode($keys[$index + 1], null),
                default => null,
            };

            if ($page->items !== [] || $next === null) {
                return new self($page->items, $next);
            }
        }

        return self::empty();
    }
}
