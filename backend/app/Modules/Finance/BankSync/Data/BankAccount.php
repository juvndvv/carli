<?php

namespace App\Modules\Finance\BankSync\Data;

use App\Modules\Finance\Domain\Enums\AccountType;

final readonly class BankAccount
{
    public const string CURRENCY = 'EUR';

    public const string NAME_SEPARATOR = ' · ';

    private const string JOINT_HOLDERS = ' & ';

    public function __construct(
        public string $uid,
        public ?string $identificationHash = null,
        public ?string $name = null,
        public ?string $iban = null,
        public ?string $currency = null,
        public ?string $type = null,
        public ?string $details = null,
        public ?string $product = null,
    ) {}

    public function shortName(): ?string
    {
        foreach ([$this->details, $this->product] as $label) {
            if ($label !== null && trim($label) !== '') {
                return self::readable($label);
            }
        }

        return null;
    }

    public function suggestedName(string $bank): string
    {
        $label = $this->shortName() ?? match (true) {
            str_contains($this->name ?? '', self::JOINT_HOLDERS) => 'Compartida',
            $this->suggestedAccountType() === AccountType::CreditCard => 'Tarjeta',
            $this->suggestedAccountType() === AccountType::Savings => 'Ahorro',
            default => 'Principal',
        };

        return $bank.self::NAME_SEPARATOR.$label;
    }

    /**
     * @return list<string>
     */
    public function legacyNames(string $bank): array
    {
        $name = trim($this->name ?? '');

        return $name === '' ? [] : ["{$bank} {$name}", $name];
    }

    public static function readable(string $label): string
    {
        $clean = trim(preg_replace('/\s+/', ' ', $label) ?? $label);

        return mb_strtoupper($clean) === $clean ? mb_convert_case(mb_strtolower($clean), MB_CASE_TITLE) : $clean;
    }

    public static function maskIban(?string $iban): ?string
    {
        if ($iban === null || $iban === '') {
            return null;
        }

        $compact = preg_replace('/\s+/', '', $iban) ?? $iban;

        return strlen($compact) <= 4 ? $compact : substr($compact, 0, 4).' •••• '.substr($compact, -4);
    }

    public function isImportable(): bool
    {
        return $this->currency === null || strtoupper($this->currency) === self::CURRENCY;
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
     * @param  array{uid: string, identification_hash?: string|null, name?: string|null, iban?: string|null, currency?: string|null, type?: string|null, details?: string|null, product?: string|null}  $data
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
            details: $data['details'] ?? null,
            product: $data['product'] ?? null,
        );
    }

    /**
     * @return array{uid: string, identification_hash: string|null, name: string|null, iban: string|null, currency: string|null, type: string|null, details: string|null, product: string|null}
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
            'details' => $this->details,
            'product' => $this->product,
        ];
    }
}
