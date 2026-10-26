<?php

namespace App\Modules\Notes\tests\Support;

use App\Models\User;
use App\Modules\Notes\Domain\Services\DefaultSections;
use Carbon\CarbonImmutable;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

final class NotesFixtures
{
    public static function user(): User
    {
        $user = User::factory()->create();
        app(DefaultSections::class)->ensure($user);

        return $user;
    }

    public static function id(): string
    {
        return (string) Str::uuid7();
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array{id: string, type: string, at: string, payload: array<string, mixed>}
     */
    public static function op(string $type, array $payload, ?string $at = null, ?string $id = null): array
    {
        return [
            'id' => $id ?? self::id(),
            'type' => $type,
            'at' => $at ?? CarbonImmutable::now()->utc()->format('Y-m-d\TH:i:s.v\Z'),
            'payload' => $payload,
        ];
    }

    /**
     * @param  list<array<string, mixed>>  $operations
     */
    public static function sync(TestCase $test, array $operations): TestResponse
    {
        return $test->postJson('/api/v1/notes/sync', ['operations' => $operations])->assertOk();
    }

    /**
     * @param  list<array<string, mixed>>  $operations
     * @return list<string>
     */
    public static function statuses(TestCase $test, array $operations): array
    {
        return self::sync($test, $operations)->json('results.*.status');
    }
}
