<?php

namespace App\Core\Pending;

use App\Models\User;

interface DigestLineProvider
{
    public function moduleId(): string;

    /**
     * @return list<string>
     */
    public function digestLines(User $user): array;
}
