<?php

namespace App\Modules\Finance\Domain\Services;

use App\Modules\Finance\Domain\Enums\ShareMode;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Models\SharedExpenseShare;
use Illuminate\Validation\ValidationException;

final class ShareCalculator
{
    /**
     * @param  array{mode: string, include_self?: bool, items: list<array{contact_id: string, percentage?: string|int|float|null, amount_cents?: int|null}>}  $spec
     * @return list<array{contact_id: string, amount_cents: int}>
     */
    public function calculate(int $expenseCents, array $spec): array
    {
        $total = Money::ofCents(abs($expenseCents));
        $items = $spec['items'];

        if ($items === []) {
            return [];
        }

        $contactIds = array_map(fn (array $item) => $item['contact_id'], $items);
        if (count(array_unique($contactIds)) !== count($contactIds)) {
            throw ValidationException::withMessages(['shares.items' => 'Cada contacto solo puede aparecer una vez.']);
        }

        $shares = match (ShareMode::from($spec['mode'])) {
            ShareMode::Equal => $this->equal($total, $contactIds, $spec['include_self'] ?? true),
            ShareMode::Percentage => $this->percentage($total, $items),
            ShareMode::Amount => $this->amount($items),
        };

        $sharedCents = array_sum(array_map(fn (array $share) => $share['amount_cents'], $shares));
        if ($sharedCents > $total->cents) {
            throw ValidationException::withMessages(['shares.items' => 'La parte compartida no puede superar el importe del gasto.']);
        }

        return array_values(array_filter($shares, fn (array $share) => $share['amount_cents'] > 0));
    }

    /**
     * @return array{mode: string, include_self?: bool, items: list<array{contact_id: string, percentage?: string|int|float|null, amount_cents?: int|null}>}|null
     */
    public static function normalize(mixed $spec): ?array
    {
        if (! is_array($spec)) {
            return null;
        }

        $items = [];
        foreach ((array) ($spec['items'] ?? []) as $item) {
            if (! is_array($item) || ! isset($item['contact_id'])) {
                continue;
            }

            $percentage = $item['percentage'] ?? null;
            $amount = $item['amount_cents'] ?? null;
            $items[] = [
                'contact_id' => (string) $item['contact_id'],
                'percentage' => is_string($percentage) || is_int($percentage) || is_float($percentage) ? $percentage : null,
                'amount_cents' => is_numeric($amount) ? (int) $amount : null,
            ];
        }

        return [
            'mode' => (string) ($spec['mode'] ?? ShareMode::Equal->value),
            'include_self' => (bool) ($spec['include_self'] ?? true),
            'items' => $items,
        ];
    }

    public static function basisPoints(string|int|float $percentage): int
    {
        $value = trim((string) $percentage);
        $value = str_replace(',', '.', $value);

        if (preg_match('/^(\d{1,3})(?:\.(\d{1,2}))?$/', $value, $matches) !== 1) {
            throw ValidationException::withMessages(['shares.items' => 'Porcentaje no válido.']);
        }

        return ((int) $matches[1]) * 100 + (int) str_pad($matches[2] ?? '0', 2, '0');
    }

    /**
     * @param  array{mode: string, include_self?: bool, items: list<array{contact_id: string, percentage?: string|int|float|null, amount_cents?: int|null}>}  $spec
     * @param  list<array{contact_id: string, amount_cents: int}>  $shares
     * @return list<array{contact_id: string, amount_cents: int, mode: string, basis_points: int|null, include_self: bool}>
     */
    public static function withSpec(array $spec, array $shares): array
    {
        $mode = ShareMode::from($spec['mode']);
        $basisPoints = [];
        foreach ($spec['items'] as $item) {
            $basisPoints[$item['contact_id']] = $mode === ShareMode::Percentage ? self::basisPoints($item['percentage'] ?? 0) : null;
        }

        return array_map(fn (array $share) => [
            ...$share,
            'mode' => $mode->value,
            'basis_points' => $basisPoints[$share['contact_id']] ?? null,
            'include_self' => $spec['include_self'] ?? true,
        ], $shares);
    }

    /**
     * @param  iterable<SharedExpenseShare>  $shares
     * @return array{mode: string, include_self: bool, items: list<array{contact_id: string, percentage: string|null, amount_cents: int|null}>}|null
     */
    public static function specFrom(iterable $shares): ?array
    {
        $spec = null;

        foreach ($shares as $share) {
            $spec ??= ['mode' => $share->mode->value, 'include_self' => $share->include_self, 'items' => []];
            $spec['items'][] = [
                'contact_id' => $share->contact_id,
                'percentage' => $share->basis_points === null ? null : sprintf('%d.%02d', intdiv($share->basis_points, 100), $share->basis_points % 100),
                'amount_cents' => $share->amount_cents,
            ];
        }

        return $spec;
    }

    /**
     * @param  list<string>  $contactIds
     * @return list<array{contact_id: string, amount_cents: int}>
     */
    private function equal(Money $total, array $contactIds, bool $includeSelf): array
    {
        $parts = $total->allocate(count($contactIds) + ($includeSelf ? 1 : 0));
        $contactParts = $includeSelf ? array_slice($parts, 1) : $parts;

        return array_map(
            fn (string $contactId, Money $part) => ['contact_id' => $contactId, 'amount_cents' => $part->cents],
            $contactIds,
            $contactParts,
        );
    }

    /**
     * @param  list<array{contact_id: string, percentage?: string|int|float|null, amount_cents?: int|null}>  $items
     * @return list<array{contact_id: string, amount_cents: int}>
     */
    private function percentage(Money $total, array $items): array
    {
        $shares = [];
        $totalBasisPoints = 0;

        foreach ($items as $item) {
            $basisPoints = self::basisPoints($item['percentage'] ?? 0);
            if ($basisPoints <= 0 || $basisPoints > 10_000) {
                throw ValidationException::withMessages(['shares.items' => 'Cada porcentaje debe estar entre 0 y 100.']);
            }
            $totalBasisPoints += $basisPoints;
            $shares[] = ['contact_id' => $item['contact_id'], 'amount_cents' => $total->percentageBasisPoints($basisPoints)->cents];
        }

        if ($totalBasisPoints > 10_000) {
            throw ValidationException::withMessages(['shares.items' => 'Los porcentajes no pueden sumar más de 100.']);
        }

        return $shares;
    }

    /**
     * @param  list<array{contact_id: string, percentage?: string|int|float|null, amount_cents?: int|null}>  $items
     * @return list<array{contact_id: string, amount_cents: int}>
     */
    private function amount(array $items): array
    {
        return array_map(function (array $item): array {
            $cents = (int) ($item['amount_cents'] ?? 0);
            if ($cents <= 0) {
                throw ValidationException::withMessages(['shares.items' => 'Cada importe compartido debe ser positivo.']);
            }

            return ['contact_id' => $item['contact_id'], 'amount_cents' => $cents];
        }, $items);
    }
}
