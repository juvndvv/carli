<?php

namespace App\Modules\Notes\Domain\Sync;

use Carbon\CarbonImmutable;

final readonly class Operation
{
    /**
     * @param  array<string, mixed>  $payload
     */
    public function __construct(
        public string $id,
        public string $type,
        public CarbonImmutable $at,
        public array $payload,
    ) {}
}
