<?php

namespace App\Modules\Notes\Models\Concerns;

use App\Modules\Notes\Domain\Support\DatabaseTime;

trait HasPreciseTimestamps
{
    public function getDateFormat(): string
    {
        return DatabaseTime::FORMAT;
    }
}
