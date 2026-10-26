<?php

namespace App\Core\Pending;

use App\Models\User;

interface DailyDigestContributor
{
    /**
     * @return array<string, int>
     */
    public function digestCounts(User $user): array;
}
