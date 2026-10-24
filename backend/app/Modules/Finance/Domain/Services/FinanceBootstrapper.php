<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;

final class FinanceBootstrapper
{
    /** @var array<string, true> */
    private array $initialized = [];

    public function __construct(
        private readonly FinanceSettingsService $settings,
        private readonly DefaultCategories $categories,
    ) {}

    public function ensure(User $user): void
    {
        if (isset($this->initialized[$user->id])) {
            return;
        }

        if (! $this->settings->exists($user)) {
            DB::transaction(function () use ($user): void {
                $this->settings->for($user);
                $this->categories->seedFor($user);
            });
        }

        $this->initialized[$user->id] = true;
    }
}
