<?php

namespace App\Core\Search;

final readonly class SearchResult
{
    public function __construct(
        public string $type,
        public string $id,
        public string $title,
        public string $url,
        public ?string $subtitle = null,
        public ?string $icon = null,
    ) {}
}
