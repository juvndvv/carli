<?php

namespace App\Modules\Finance\BankSync\Data;

final readonly class PsuContext
{
    public function __construct(
        public string $ipAddress,
        public ?string $userAgent = null,
    ) {}

    /**
     * @return array<string, string>
     */
    public function headers(): array
    {
        return array_filter([
            'Psu-Ip-Address' => $this->ipAddress,
            'Psu-User-Agent' => $this->userAgent,
        ], fn (?string $value) => $value !== null && $value !== '');
    }
}
