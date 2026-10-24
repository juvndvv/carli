<?php

namespace App\Modules\Finance\Domain\ValueObjects;

use InvalidArgumentException;
use JsonSerializable;
use Stringable;

final readonly class Money implements JsonSerializable, Stringable
{
    public function __construct(public int $cents) {}

    public static function ofCents(int $cents): self
    {
        return new self($cents);
    }

    public static function zero(): self
    {
        return new self(0);
    }

    public static function parse(string $amount): self
    {
        $normalized = str_replace(['.', ' ', "\u{00A0}", '€'], '', trim($amount));
        $normalized = str_replace(',', '.', $normalized);

        if (preg_match('/^(-)?(\d+)(?:\.(\d{1,2}))?$/', $normalized, $matches) !== 1) {
            throw new InvalidArgumentException("Invalid money amount [{$amount}].");
        }

        $cents = ((int) $matches[2]) * 100 + (int) str_pad($matches[3] ?? '0', 2, '0');

        return new self($matches[1] === '-' ? -$cents : $cents);
    }

    public function plus(self|int $other): self
    {
        return new self($this->cents + self::centsOf($other));
    }

    public function minus(self|int $other): self
    {
        return new self($this->cents - self::centsOf($other));
    }

    public function negate(): self
    {
        return new self(-$this->cents);
    }

    public function abs(): self
    {
        return new self(abs($this->cents));
    }

    public function multiply(int $numerator, int $denominator = 1): self
    {
        if ($denominator === 0) {
            throw new InvalidArgumentException('Denominator must not be zero.');
        }

        return new self(self::roundedDivision($this->cents * $numerator, $denominator));
    }

    public function percentageBasisPoints(int $basisPoints): self
    {
        return $this->multiply($basisPoints, 10_000);
    }

    /**
     * @return list<self>
     */
    public function allocate(int $parts): array
    {
        if ($parts < 1) {
            throw new InvalidArgumentException('Parts must be at least one.');
        }

        $sign = $this->cents < 0 ? -1 : 1;
        $absolute = abs($this->cents);
        $base = intdiv($absolute, $parts);
        $remainder = $absolute % $parts;

        $allocations = [];
        for ($index = 0; $index < $parts; $index++) {
            $allocations[] = new self($sign * ($base + ($index < $remainder ? 1 : 0)));
        }

        return $allocations;
    }

    public function ratioBasisPoints(self|int $total): ?int
    {
        $totalCents = self::centsOf($total);

        if ($totalCents === 0) {
            return null;
        }

        return self::roundedDivision($this->cents * 10_000, $totalCents);
    }

    public function isZero(): bool
    {
        return $this->cents === 0;
    }

    public function isNegative(): bool
    {
        return $this->cents < 0;
    }

    public function isPositive(): bool
    {
        return $this->cents > 0;
    }

    public function equals(self $other): bool
    {
        return $this->cents === $other->cents;
    }

    public function format(): string
    {
        $absolute = abs($this->cents);
        $units = number_format(intdiv($absolute, 100), 0, ',', '.');
        $decimals = str_pad((string) ($absolute % 100), 2, '0', STR_PAD_LEFT);

        return ($this->cents < 0 ? '-' : '').$units.','.$decimals.' €';
    }

    public function __toString(): string
    {
        return $this->format();
    }

    public function jsonSerialize(): int
    {
        return $this->cents;
    }

    public static function roundedDivision(int $dividend, int $divisor): int
    {
        if ($divisor < 0) {
            $dividend = -$dividend;
            $divisor = -$divisor;
        }

        $quotient = intdiv($dividend, $divisor);
        $remainder = $dividend % $divisor;

        if (abs($remainder) * 2 >= $divisor) {
            $quotient += $dividend < 0 ? -1 : 1;
        }

        return $quotient;
    }

    private static function centsOf(self|int $value): int
    {
        return $value instanceof self ? $value->cents : $value;
    }
}
