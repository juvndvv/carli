<?php

namespace App\Modules\Notes\Http\Requests;

use App\Modules\Notes\Domain\Sync\Operation;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Http\FormRequest;

final class SyncRequest extends FormRequest
{
    public const int MAX_OPERATIONS = 500;

    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'operations' => ['present', 'array', 'list', 'max:'.self::MAX_OPERATIONS],
            'operations.*' => ['required', 'array'],
            'operations.*.id' => ['required', 'uuid'],
            'operations.*.type' => ['required', 'string', 'max:64'],
            'operations.*.at' => ['required', 'date'],
            'operations.*.payload' => ['present', 'array'],
        ];
    }

    /**
     * @return list<Operation>
     */
    public function operations(): array
    {
        /** @var list<array{id: string, type: string, at: string, payload: array<string, mixed>}> $operations */
        $operations = $this->validated('operations');

        return array_map(fn (array $operation) => new Operation(
            id: strtolower($operation['id']),
            type: $operation['type'],
            at: CarbonImmutable::parse($operation['at'], 'UTC'),
            payload: $operation['payload'],
        ), $operations);
    }
}
