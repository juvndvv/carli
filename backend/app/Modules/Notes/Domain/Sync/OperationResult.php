<?php

namespace App\Modules\Notes\Domain\Sync;

use App\Modules\Notes\Domain\Enums\OperationStatus;

final readonly class OperationResult
{
    public function __construct(
        public string $id,
        public OperationStatus $status,
        public ?string $error = null,
    ) {}

    /**
     * @return array{id: string, status: string, error: string|null}
     */
    public function toArray(): array
    {
        return ['id' => $this->id, 'status' => $this->status->value, 'error' => $this->error];
    }
}
