<?php

namespace App\Modules\Notes\Domain\Sync\Handlers;

use App\Models\User;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Models\ShoppingSection;

final class SectionUpsert extends Handler
{
    public function handle(User $user, Operation $operation): void
    {
        $data = $this->validate($operation->payload, [
            'id' => ['required', 'uuid'],
            'name' => ['sometimes', 'string', 'filled', 'max:255'],
            'position' => ['sometimes', 'integer'],
        ]);

        $section = $this->section($user, (string) $data['id']) ?? new ShoppingSection;
        $this->requireOnCreate($section, $data, 'name', 'La sección necesita un nombre.');
        $this->ensureFresh($section, $operation->at);

        if (! $section->exists) {
            $section->id = (string) $data['id'];
            $section->user_id = $user->id;
            $section->position = 0;
        }

        $section->fill(array_intersect_key($data, array_flip(['name', 'position'])));
        $this->persist($section, $operation->at);
    }
}
