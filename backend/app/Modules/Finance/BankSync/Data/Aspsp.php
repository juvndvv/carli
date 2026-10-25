<?php

namespace App\Modules\Finance\BankSync\Data;

final readonly class Aspsp
{
    public const int DEFAULT_CONSENT_DAYS = 90;

    public const int MAX_CONSENT_DAYS = 180;

    /**
     * @param  list<string>  $psuTypes
     */
    public function __construct(
        public string $name,
        public string $country,
        public ?string $logo = null,
        public ?int $maximumConsentValiditySeconds = null,
        public array $psuTypes = [],
    ) {}

    public function consentDays(): int
    {
        if ($this->maximumConsentValiditySeconds === null || $this->maximumConsentValiditySeconds <= 0) {
            return self::DEFAULT_CONSENT_DAYS;
        }

        return max(1, min(self::MAX_CONSENT_DAYS, intdiv($this->maximumConsentValiditySeconds, 86_400)));
    }

    /**
     * @return array{name: string, country: string, logo: string|null, consent_days: int}
     */
    public function toArray(): array
    {
        return [
            'name' => $this->name,
            'country' => $this->country,
            'logo' => $this->logo,
            'consent_days' => $this->consentDays(),
        ];
    }
}
