<?php

namespace App\Core\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Notifications\DatabaseNotification;

/**
 * @mixin DatabaseNotification
 */
class NotificationResource extends JsonResource
{
    /**
     * @return array{id: string, module: string|null, type: string|null, title: string|null, body: string|null, url: string|null, read_at: string|null, created_at: string|null}
     */
    public function toArray(Request $request): array
    {
        /** @var array<string, mixed> $data */
        $data = (array) $this->data;

        return [
            'id' => (string) $this->id,
            'module' => self::stringOrNull($data['module'] ?? null),
            'type' => self::stringOrNull($data['type'] ?? null),
            'title' => self::stringOrNull($data['title'] ?? null),
            'body' => self::stringOrNull($data['body'] ?? null),
            'url' => self::stringOrNull($data['url'] ?? null),
            'read_at' => $this->read_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    private static function stringOrNull(mixed $value): ?string
    {
        return is_string($value) ? $value : null;
    }
}
