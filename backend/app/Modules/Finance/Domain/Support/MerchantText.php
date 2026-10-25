<?php

namespace App\Modules\Finance\Domain\Support;

use Illuminate\Support\Str;

final class MerchantText
{
    public static function of(?string $payee, ?string $description): string
    {
        $merchant = self::normalize($payee);

        return $merchant !== '' ? $merchant : self::normalize($description);
    }

    public static function normalize(?string $text): string
    {
        if ($text === null || trim($text) === '') {
            return '';
        }

        $upper = Str::upper(Str::ascii($text));
        $letters = preg_replace('/[^A-Z\s]+/', ' ', $upper) ?? '';
        $tokens = array_filter(
            preg_split('/\s+/', $letters) ?: [],
            fn (string $token) => $token !== '' && preg_match('/^X+$/', $token) !== 1,
        );

        return implode(' ', $tokens);
    }

    public static function contains(string $normalizedText, string $normalizedPattern): bool
    {
        if ($normalizedPattern === '' || $normalizedText === '') {
            return false;
        }

        return str_contains(' '.$normalizedText.' ', ' '.$normalizedPattern.' ');
    }
}
