<?php

namespace App\Modules\Tasks\Domain\Enums;

enum TemplatePolicy: string
{
    case Replace = 'replace';

    case Accumulate = 'accumulate';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }
}
