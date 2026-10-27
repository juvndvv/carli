<?php

namespace App\Modules\Habits\Models\Concerns;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Auth;

trait BelongsToUser
{
    public static function bootBelongsToUser(): void
    {
        static::addGlobalScope('user', function (Builder $builder): void {
            $userId = Auth::id();

            if ($userId !== null) {
                $builder->where($builder->qualifyColumn('user_id'), $userId);
            }
        });

        static::creating(function (self $model): void {
            if ($model->getAttribute('user_id') === null && Auth::id() !== null) {
                $model->setAttribute('user_id', Auth::id());
            }
        });
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @param  Builder<static>  $query
     */
    public function scopeOwnedBy(Builder $query, User|string $user): void
    {
        $query->withoutGlobalScope('user')->where($query->qualifyColumn('user_id'), $user instanceof User ? $user->id : $user);
    }
}
