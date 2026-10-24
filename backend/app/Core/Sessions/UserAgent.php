<?php

namespace App\Core\Sessions;

final readonly class UserAgent
{
    private const array BROWSERS = [
        'Edg/' => 'Edge',
        'OPR/' => 'Opera',
        'Firefox/' => 'Firefox',
        'CriOS/' => 'Chrome',
        'Chrome/' => 'Chrome',
        'Safari/' => 'Safari',
    ];

    private const array PLATFORMS = [
        'iPhone' => 'iOS',
        'iPad' => 'iPadOS',
        'Android' => 'Android',
        'Windows' => 'Windows',
        'Macintosh' => 'macOS',
        'CrOS' => 'ChromeOS',
        'Linux' => 'Linux',
    ];

    public function __construct(private ?string $userAgent) {}

    public function browser(): ?string
    {
        return $this->match(self::BROWSERS);
    }

    public function platform(): ?string
    {
        return $this->match(self::PLATFORMS);
    }

    public function isMobile(): bool
    {
        return in_array($this->platform(), ['iOS', 'Android'], true);
    }

    public function label(): string
    {
        $browser = $this->browser();
        $platform = $this->platform();

        return match (true) {
            $browser !== null && $platform !== null => "{$browser} en {$platform}",
            $browser !== null => $browser,
            $platform !== null => $platform,
            default => 'Dispositivo desconocido',
        };
    }

    /**
     * @param  array<string, string>  $needles
     */
    private function match(array $needles): ?string
    {
        if ($this->userAgent === null || $this->userAgent === '') {
            return null;
        }

        foreach ($needles as $needle => $name) {
            if (str_contains($this->userAgent, $needle)) {
                return $name;
            }
        }

        return null;
    }
}
