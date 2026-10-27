<?php

namespace App\Modules\Habits\Search;

use App\Core\Search\ModuleSearcher;
use App\Core\Search\SearchResult;
use App\Models\User;
use App\Modules\Habits\Domain\Evaluation\Goal;
use App\Modules\Habits\Domain\Support\GoalDescriber;
use App\Modules\Habits\Models\Habit;

final class HabitsSearcher implements ModuleSearcher
{
    public function moduleId(): string
    {
        return 'habits';
    }

    public function search(User $user, string $query, int $limit): array
    {
        $term = trim($query);
        if ($term === '') {
            return [];
        }

        $like = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term).'%';

        return array_values(Habit::query()->ownedBy($user)->with('goals')
            ->where('name', 'ILIKE', $like)
            ->orderByRaw('archived_at IS NOT NULL')
            ->orderBy('name')
            ->limit($limit)
            ->get()
            ->map(fn (Habit $habit) => new SearchResult(
                type: 'habit',
                id: $habit->id,
                title: $habit->name,
                url: '/habitos/habito/'.$habit->id,
                subtitle: GoalDescriber::describe($habit->kind, $habit->unit, Goal::fromModel($habit->currentGoal())),
                icon: $habit->icon,
            ))
            ->all());
    }
}
