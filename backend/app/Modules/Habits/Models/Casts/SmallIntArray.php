<?php

namespace App\Modules\Habits\Models\Casts;

use Illuminate\Contracts\Database\Eloquent\CastsAttributes;
use Illuminate\Database\Eloquent\Model;

/**
 * @implements CastsAttributes<list<int>|null, list<int>|null>
 */
final class SmallIntArray implements CastsAttributes
{
    /**
     * @param  array<string, mixed>  $attributes
     * @return list<int>|null
     */
    public function get(Model $model, string $key, mixed $value, array $attributes): ?array
    {
        if (! is_string($value)) {
            return null;
        }

        $inner = trim($value, '{}');

        return $inner === '' ? [] : array_map(intval(...), explode(',', $inner));
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function set(Model $model, string $key, mixed $value, array $attributes): ?string
    {
        if (! is_array($value)) {
            return null;
        }

        $days = array_values(array_unique(array_map(intval(...), $value)));
        sort($days);

        return '{'.implode(',', $days).'}';
    }
}
