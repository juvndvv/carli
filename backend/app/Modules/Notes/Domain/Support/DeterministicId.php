<?php

namespace App\Modules\Notes\Domain\Support;

use Ramsey\Uuid\Uuid;

final class DeterministicId
{
    public const string NAMESPACE = '6f0b5c3e-2d4a-5b8e-9c1f-7a3d2e1b0c9d';

    public static function for(string $name): string
    {
        return Uuid::uuid5(self::NAMESPACE, $name)->toString();
    }
}
