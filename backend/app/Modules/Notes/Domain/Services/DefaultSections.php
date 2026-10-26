<?php

namespace App\Modules\Notes\Domain\Services;

use App\Models\User;
use App\Modules\Notes\Domain\Support\DatabaseTime;
use App\Modules\Notes\Domain\Support\DeterministicId;
use App\Modules\Notes\Models\Note;
use App\Modules\Notes\Models\ShoppingSection;
use Carbon\CarbonImmutable;

final class DefaultSections
{
    public const array NAMES = [
        'Fruta y verdura',
        'Carne y pescado',
        'Lácteos y huevos',
        'Panadería',
        'Despensa',
        'Congelados',
        'Bebidas',
        'Limpieza',
        'Higiene',
        'Otros',
    ];

    /** @var array<string, true> */
    private array $initialized = [];

    public function ensure(User $user): void
    {
        if (isset($this->initialized[$user->id])) {
            return;
        }

        if (! ShoppingSection::query()->ownedBy($user)->exists() && ! Note::query()->ownedBy($user)->exists()) {
            $this->seedFor($user);
        }

        $this->initialized[$user->id] = true;
    }

    public function seedFor(User $user): void
    {
        $now = DatabaseTime::format(CarbonImmutable::now());

        ShoppingSection::query()->insertOrIgnore(array_map(fn (string $name, int $position) => [
            'id' => DeterministicId::for("section:{$user->id}:{$position}"),
            'user_id' => $user->id,
            'name' => $name,
            'position' => $position,
            'created_at' => $now,
            'updated_at' => $now,
        ], self::NAMES, array_keys(self::NAMES)));
    }
}
