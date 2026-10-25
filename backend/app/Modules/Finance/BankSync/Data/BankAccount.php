<?php

namespace App\Modules\Finance\BankSync\Data;

use App\Modules\Finance\Domain\Enums\AccountType;

final readonly class BankAccount
{
    public function __construct(
        public string $uid,
        public ?string $identificationHash = null,
        public ?string $name = null,
        public ?string $iban = null,
        public ?string $currency = null,
        public ?string $type = null,
    ) {}

    public static function maskIban(?string $iban): ?string
    {
        if ($iban === null || $iban === '') {
            return null;
        }

        $compact = preg_replace('/\s+/', '', $iban) ?? $iban;

        return strlen($compact) <= 4 ? $compact : substr($compact, 0, 4).' •••• '.substr($compact, -4);
    }

    public function suggestedAccountType(): AccountType
    {
        return match ($this->type) {
            'CARD' => AccountType::CreditCard,
            'SVGS', 'MOMA', 'ONDP' => AccountType::Savings,
            default => AccountType::Checking,
        };
    }

    /**
     * @param  array{uid: string, identification_hash?: string|null, name?: string|null, iban?: string|null, currency?: string|null, type?: string|null}  $data
     */
    public static function fromArray(array $data): self
    {
        return new self(
            uid: $data['uid'],
            identificationHash: $data['identification_hash'] ?? null,
            name: $data['name'] ?? null,
            iban: $data['iban'] ?? null,
            currency: $data['currency'] ?? null,
            type: $data['type'] ?? null,
        );
    }

    /**
     * @return array{uid: string, identification_hash: string|null, name: string|null, iban: string|null, currency: string|null, type: string|null}
     */
    public function toArray(): array
    {
        return [
            'uid' => $this->uid,
            'identification_hash' => $this->identificationHash,
            'name' => $this->name,
            'iban' => $this->iban,
            'currency' => $this->currency,
            'type' => $this->type,
        ];
    }
}
