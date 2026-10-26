<?php

namespace App\Modules\Notes\Domain\Enums;

enum CheckedBehavior: string
{
    case Move = 'move';

    case Inline = 'inline';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
