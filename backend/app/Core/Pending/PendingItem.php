<?php

namespace App\Core\Pending;

final readonly class PendingItem
{
    /**
     * @param  array<string, mixed>  $meta
     */
    public function __construct(
        public string $module,
        public string $type,
        public string $id,
        public string $title,
        public string $date,
        public string $route,
        public ?string $subtitle = null,
        public ?int $amountCents = null,
        public array $meta = [],
    ) {}

    /**
     * @return array{module: string, type: string, id: string, title: string, subtitle: string|null, amount_cents: int|null, date: string, route: string, meta: array<string, mixed>}
     */
    public function toArray(): array
    {
        return [
            'module' => $this->module,
            'type' => $this->type,
            'id' => $this->id,
            'title' => $this->title,
            'subtitle' => $this->subtitle,
            'amount_cents' => $this->amountCents,
            'date' => $this->date,
            'route' => $this->route,
            'meta' => $this->meta,
        ];
    }
}
