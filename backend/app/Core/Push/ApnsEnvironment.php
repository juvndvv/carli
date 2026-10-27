<?php

namespace App\Core\Push;

enum ApnsEnvironment: string
{
    case Sandbox = 'sandbox';
    case Production = 'production';

    public function host(): string
    {
        return match ($this) {
            self::Sandbox => 'https://api.sandbox.push.apple.com',
            self::Production => 'https://api.push.apple.com',
        };
    }
}
