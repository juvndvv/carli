<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Models\Tag;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class TagService
{
    /**
     * @param  list<string>  $names
     * @return list<string>
     */
    public function resolveIds(User|string $user, array $names): array
    {
        $userId = $user instanceof User ? $user->id : $user;
        $ids = [];

        foreach (array_unique(array_filter(array_map(fn (string $name) => self::normalize($name), $names))) as $name) {
            $tag = Tag::query()->ownedBy($userId)->where('name', $name)->first();

            if ($tag === null) {
                $tag = new Tag(['name' => $name]);
                $tag->user_id = $userId;
                $tag->save();
            }

            $ids[] = $tag->id;
        }

        return $ids;
    }

    public function create(User $user, string $name, ?string $color): Tag
    {
        $name = self::normalize($name);
        $this->assertNameAvailable($user->id, $name, null);

        $tag = new Tag(['name' => $name, 'color' => $color]);
        $tag->user_id = $user->id;
        $tag->save();

        return $tag;
    }

    /**
     * @param  array{name?: string, color?: string|null}  $data
     */
    public function update(Tag $tag, array $data): Tag
    {
        if (array_key_exists('name', $data)) {
            $name = self::normalize($data['name']);
            $this->assertNameAvailable($tag->user_id, $name, $tag->id);
            $tag->name = $name;
        }

        if (array_key_exists('color', $data)) {
            $tag->color = $data['color'];
        }

        $tag->save();

        return $tag;
    }

    public function merge(Tag $source, Tag $target): Tag
    {
        if ($source->is($target)) {
            throw ValidationException::withMessages(['into_tag_id' => 'No puedes fusionar una etiqueta consigo misma.']);
        }

        DB::transaction(function () use ($source, $target): void {
            DB::statement(
                'INSERT INTO finance.transaction_tag (transaction_id, tag_id) SELECT transaction_id, ? FROM finance.transaction_tag WHERE tag_id = ? ON CONFLICT DO NOTHING',
                [$target->id, $source->id],
            );
            $source->delete();
        });

        return $target;
    }

    public function delete(Tag $tag): void
    {
        $tag->delete();
    }

    public static function normalize(string $name): string
    {
        return mb_strtolower(trim(ltrim(trim($name), '#')));
    }

    private function assertNameAvailable(string $userId, string $name, ?string $exceptId): void
    {
        $query = Tag::query()->ownedBy($userId)->where('name', $name);

        if ($exceptId !== null) {
            $query->whereKeyNot($exceptId);
        }

        if ($query->exists()) {
            throw ValidationException::withMessages(['name' => 'Ya existe una etiqueta con ese nombre. Puedes fusionarlas.']);
        }
    }
}
