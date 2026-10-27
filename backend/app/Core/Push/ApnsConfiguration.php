<?php

namespace App\Core\Push;

final class ApnsConfiguration
{
    public static function isConfigured(): bool
    {
        return self::keyId() !== null
            && self::teamId() !== null
            && self::bundleId() !== null
            && self::privateKey() !== null;
    }

    public static function keyId(): ?string
    {
        return self::string('key_id');
    }

    public static function teamId(): ?string
    {
        return self::string('team_id');
    }

    public static function bundleId(): ?string
    {
        return self::string('bundle_id');
    }

    public static function privateKey(): ?string
    {
        $path = self::string('private_key_path');

        if ($path === null || ! is_file($path) || ! is_readable($path)) {
            return null;
        }

        $key = file_get_contents($path);

        return is_string($key) && trim($key) !== '' ? $key : null;
    }

    public static function timeoutSeconds(): int
    {
        $timeout = config('services.apns.timeout');

        return is_numeric($timeout) ? (int) $timeout : 10;
    }

    private static function string(string $key): ?string
    {
        $value = config("services.apns.{$key}");

        return is_string($value) && $value !== '' ? $value : null;
    }
}
