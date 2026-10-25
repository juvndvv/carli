<?php

namespace App\Core\Pending;

use App\Models\User;

interface PendingItemsProvider
{
    public function moduleId(): string;

    /**
     * @return array<string, int>
     */
    public function counts(User $user): array;

    public function items(User $user, ?string $type, ?string $cursor): PendingPage;

    public function describe(string $type, int $count): string;
}
