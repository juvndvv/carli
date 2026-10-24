<?php

namespace App\Modules\Finance\Queries;

use App\Modules\Finance\Models\Transaction;
use Illuminate\Support\Str;

final class TransactionCursor
{
    public static function encode(Transaction $transaction): string
    {
        return rtrim(strtr(base64_encode($transaction->date->toDateString().'|'.$transaction->id), '+/', '-_'), '=');
    }

    /**
     * @return array{date: string, id: string}|null
     */
    public static function decode(mixed $cursor): ?array
    {
        if (! is_string($cursor) || $cursor === '') {
            return null;
        }

        $decoded = base64_decode(strtr($cursor, '-_', '+/'), true);
        if ($decoded === false) {
            return null;
        }

        $parts = explode('|', $decoded);
        if (count($parts) !== 2 || preg_match('/^\d{4}-\d{2}-\d{2}$/', $parts[0]) !== 1 || ! Str::isUuid($parts[1])) {
            return null;
        }

        return ['date' => $parts[0], 'id' => $parts[1]];
    }
}
