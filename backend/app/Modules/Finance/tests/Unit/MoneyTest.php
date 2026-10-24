<?php

use App\Modules\Finance\Domain\ValueObjects\Money;

it('formats cents in es-ES with thousands grouping', function (int $cents, string $expected) {
    expect(Money::ofCents($cents)->format())->toBe($expected);
})->with([
    [0, '0,00 €'],
    [5, '0,05 €'],
    [4250, '42,50 €'],
    [-4250, '-42,50 €'],
    [269500, '2.695,00 €'],
    [123456789, '1.234.567,89 €'],
]);

it('parses Spanish formatted amounts into cents', function (string $input, int $expected) {
    expect(Money::parse($input)->cents)->toBe($expected);
})->with([
    ['1.234,56 €', 123456],
    ['-42,5', -4250],
    ['13', 1300],
    ['0,99', 99],
]);

it('rejects malformed amounts', function () {
    Money::parse('12,345');
})->throws(InvalidArgumentException::class);

it('performs integer arithmetic', function () {
    $money = Money::ofCents(1000);

    expect($money->plus(250)->cents)->toBe(1250)
        ->and($money->minus(Money::ofCents(1500))->cents)->toBe(-500)
        ->and($money->negate()->cents)->toBe(-1000)
        ->and($money->negate()->abs()->cents)->toBe(1000)
        ->and($money->isPositive())->toBeTrue()
        ->and(Money::zero()->isZero())->toBeTrue();
});

it('rounds half away from zero when multiplying', function () {
    expect(Money::ofCents(1001)->multiply(1, 2)->cents)->toBe(501)
        ->and(Money::ofCents(-1001)->multiply(1, 2)->cents)->toBe(-501)
        ->and(Money::ofCents(1000)->multiply(1, 3)->cents)->toBe(333)
        ->and(Money::ofCents(8000)->percentageBasisPoints(5000)->cents)->toBe(4000);
});

it('allocates without losing cents', function () {
    $parts = Money::ofCents(1000)->allocate(3);

    expect(array_map(fn (Money $part) => $part->cents, $parts))->toBe([334, 333, 333])
        ->and(array_map(fn (Money $part) => $part->cents, Money::ofCents(-1000)->allocate(3)))->toBe([-334, -333, -333]);
});

it('computes ratios in basis points', function () {
    expect(Money::ofCents(800)->ratioBasisPoints(1000))->toBe(8000)
        ->and(Money::ofCents(1)->ratioBasisPoints(3))->toBe(3333)
        ->and(Money::ofCents(1)->ratioBasisPoints(0))->toBeNull();
});
