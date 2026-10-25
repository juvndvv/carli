<?php

namespace App\Core\Pending;

final class PendingCursor
{
    public static function encode(string $segment, ?string $inner): string
    {
        return rtrim(strtr(base64_encode((string) json_encode(['s' => $segment, 'c' => $inner])), '+/', '-_'), '=');
    }

    /**
     * @return array{segment: string, inner: string|null}|null
     */
    public static function decode(?string $cursor): ?array
    {
        if ($cursor === null || $cursor === '') {
            return null;
        }

        $decoded = base64_decode(strtr($cursor, '-_', '+/'), true);
        $payload = $decoded === false ? null : json_decode($decoded, true);

        if (! is_array($payload) || ! is_string($payload['s'] ?? null) || ! (is_string($payload['c'] ?? null) || ($payload['c'] ?? null) === null)) {
            return null;
        }

        return ['segment' => $payload['s'], 'inner' => $payload['c'] ?? null];
    }
}
