<?php

use App\Modules\Notes\Domain\Enums\RestockMode;
use App\Modules\Notes\Domain\Services\RestockService;
use App\Modules\Notes\Domain\Support\DeterministicId;
use Carbon\CarbonImmutable;

/**
 * @return array<string, array{array<string, mixed>}>
 */
function restockCases(): array
{
    $fixture = json_decode((string) file_get_contents(__DIR__.'/../Fixtures/restock_cases.json'), true);

    return collect($fixture['cases'])->mapWithKeys(fn (array $case) => [$case['name'] => [$case]])->all();
}

it('uses the shared namespace and time zone', function () {
    $fixture = json_decode((string) file_get_contents(__DIR__.'/../Fixtures/restock_cases.json'), true);

    expect($fixture['namespace'])->toBe(DeterministicId::NAMESPACE)
        ->and($fixture['timezone'])->toBe('Europe/Madrid');
});

it('matches the shared restock fixture', function (array $case) {
    $lastBoughtAt = $case['last_bought_at'] === null ? null : CarbonImmutable::parse($case['last_bought_at']);

    foreach (['00:00:00', '12:00:00', '23:59:59'] as $time) {
        $today = CarbonImmutable::parse($case['today'].' '.$time, 'Europe/Madrid');

        expect(RestockService::isDue(RestockMode::from($case['restock_mode']), $case['restock_interval_days'], $lastBoughtAt, $today))->toBe($case['due']);
    }

    if ($lastBoughtAt === null) {
        expect($case['cycle_key'])->toBeNull()->and($case['item_id'])->toBeNull();

        return;
    }

    $cycleKey = RestockService::cycleKey($case['product_id'], $lastBoughtAt);

    expect($cycleKey)->toBe($case['cycle_key'])
        ->and(RestockService::itemId($cycleKey))->toBe($case['item_id']);
})->with(restockCases());
