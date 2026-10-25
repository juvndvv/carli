<?php

namespace App\Modules\Finance\BankSync\Data;

use InvalidArgumentException;

final class BankAmount
{
    public static function toCents(string|int|float $amount): int
    {
        $text = is_string($amount) ? trim($amount) : (is_int($amount) ? (string) $amount : number_format($amount, 2, '.', ''));

        if (preg_match('/^([+-])?(\d+)(?:\.(\d+))?$/', $text, $matches) !== 1) {
            throw new InvalidArgumentException("Invalid bank amount [{$text}].");
        }

        $fraction = $matches[3] ?? '';
        $cents = ((int) $matches[2]) * 100 + (int) str_pad(substr($fraction, 0, 2), 2, '0');

        if (strlen($fraction) > 2 && (int) $fraction[2] >= 5) {
            $cents++;
        }

        return $matches[1] === '-' ? -$cents : $cents;
    }
}
