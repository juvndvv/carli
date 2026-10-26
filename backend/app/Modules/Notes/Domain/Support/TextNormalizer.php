<?php

namespace App\Modules\Notes\Domain\Support;

use Illuminate\Support\Str;

final class TextNormalizer
{
    public static function normalize(string $text): string
    {
        return trim((string) preg_replace('/\s+/u', ' ', Str::lower(Str::ascii($text))));
    }
}
