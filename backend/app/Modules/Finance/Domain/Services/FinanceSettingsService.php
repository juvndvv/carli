<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Models\FinanceSetting;

final class FinanceSettingsService
{
    /** @var array<string, FinanceSetting> */
    private array $cache = [];

    public function for(User|string $user): FinanceSetting
    {
        $userId = $user instanceof User ? $user->id : $user;

        if (isset($this->cache[$userId]) && $this->cache[$userId]->exists) {
            return $this->cache[$userId];
        }

        $settings = FinanceSetting::query()->ownedBy($userId)->first();

        if ($settings === null) {
            $settings = new FinanceSetting;
            $settings->user_id = $userId;
            $settings->save();
            $settings->refresh();
        }

        return $this->cache[$userId] = $settings;
    }

    public function lockFor(User|string $user): FinanceSetting
    {
        $userId = $user instanceof User ? $user->id : $user;
        $this->for($userId);

        $settings = FinanceSetting::query()->ownedBy($userId)->lockForUpdate()->firstOrFail();

        return $this->cache[$userId] = $settings;
    }

    public function forget(User|string $user): void
    {
        unset($this->cache[$user instanceof User ? $user->id : $user]);
    }

    public function exists(User $user): bool
    {
        return FinanceSetting::query()->ownedBy($user)->exists();
    }
}
