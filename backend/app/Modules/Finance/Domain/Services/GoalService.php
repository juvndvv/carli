<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\GoalContribution;
use App\Modules\Finance\Models\SavingsGoal;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\GoalReached;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class GoalService
{
    private const array MILESTONES = [25, 50, 75, 100];

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data): SavingsGoal
    {
        $goal = new SavingsGoal;
        $goal->user_id = $user->id;
        $goal->fill($this->attributes($data));
        $this->assertValid($goal);
        $goal->save();
        $this->checkMilestones($goal);

        return $goal->refresh();
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(SavingsGoal $goal, array $data): SavingsGoal
    {
        $goal->fill($this->attributes($data));
        $this->assertValid($goal);

        if ($goal->isDirty(['target_cents', 'account_id'])) {
            $goal->notified_milestone = 0;
            $goal->achieved_at = null;
        }

        $goal->save();
        $this->checkMilestones($goal);

        return $goal->refresh();
    }

    /**
     * @param  array{amount_cents: int, date?: string|null, note?: string|null, transaction_id?: string|null}  $data
     */
    public function contribute(SavingsGoal $goal, array $data): GoalContribution
    {
        if ($goal->account_id !== null) {
            throw ValidationException::withMessages(['goal' => 'Este objetivo sigue el saldo de una cuenta: las aportaciones se hacen con transferencias a esa cuenta.']);
        }

        if (isset($data['transaction_id']) && ! Transaction::query()->ownedBy($goal->user_id)->whereKey($data['transaction_id'])->exists()) {
            throw ValidationException::withMessages(['transaction_id' => 'El movimiento no existe.']);
        }

        return DB::transaction(function () use ($goal, $data): GoalContribution {
            $contribution = $goal->contributions()->create([
                'amount_cents' => $data['amount_cents'],
                'date' => $data['date'] ?? SpanishCalendar::today()->toDateString(),
                'note' => $data['note'] ?? null,
                'transaction_id' => $data['transaction_id'] ?? null,
            ]);
            $this->checkMilestones($goal);

            return $contribution;
        });
    }

    public function removeContribution(GoalContribution $contribution): void
    {
        $contribution->delete();
    }

    public function savedCents(SavingsGoal $goal): int
    {
        if ($goal->account_id !== null) {
            $account = Account::query()->withoutGlobalScopes()->find($goal->account_id);

            return $account?->balanceCents() ?? 0;
        }

        return (int) $goal->contributions()->sum('amount_cents');
    }

    /**
     * @return array{saved_cents: int, remaining_cents: int, progress_bp: int, months_left: int|null, monthly_needed_cents: int|null}
     */
    public function progress(SavingsGoal $goal, ?CarbonImmutable $today = null): array
    {
        $today ??= SpanishCalendar::today();
        $saved = $this->savedCents($goal);
        $remaining = max(0, $goal->target_cents - $saved);
        $progress = min(10_000, max(0, Money::ofCents($saved)->ratioBasisPoints($goal->target_cents) ?? 0));

        $monthsLeft = null;
        $monthlyNeeded = null;
        if ($goal->target_date !== null) {
            $monthsLeft = max(0, ($goal->target_date->year - $today->year) * 12 + $goal->target_date->month - $today->month);
            if ($goal->target_date->day >= $today->day && $goal->target_date->greaterThan($today)) {
                $monthsLeft++;
            }
            $monthsLeft = max(1, $monthsLeft);
            $monthlyNeeded = intdiv($remaining + $monthsLeft - 1, $monthsLeft);
        }

        return [
            'saved_cents' => $saved,
            'remaining_cents' => $remaining,
            'progress_bp' => $progress,
            'months_left' => $monthsLeft,
            'monthly_needed_cents' => $monthlyNeeded,
        ];
    }

    public function checkMilestones(SavingsGoal $goal): void
    {
        $progress = $this->progress($goal)['progress_bp'];
        $reached = 0;

        foreach (self::MILESTONES as $milestone) {
            if ($progress >= $milestone * 100) {
                $reached = $milestone;
            }
        }

        if ($reached === 100 && $goal->achieved_at === null) {
            $goal->achieved_at = CarbonImmutable::now();
        }

        if ($reached <= $goal->notified_milestone) {
            $goal->save();

            return;
        }

        $goal->notified_milestone = $reached;
        $goal->save();

        User::query()->find($goal->user_id)?->notify(new GoalReached($goal->name, $goal->id, $reached));
    }

    public function checkGoalsForAccount(string $userId, string $accountId): void
    {
        SavingsGoal::query()->ownedBy($userId)->where('account_id', $accountId)->get()
            ->each(fn (SavingsGoal $goal) => $this->checkMilestones($goal));
    }

    private function assertValid(SavingsGoal $goal): void
    {
        if ($goal->account_id !== null && ! Account::query()->ownedBy($goal->user_id)->whereKey($goal->account_id)->exists()) {
            throw ValidationException::withMessages(['account_id' => 'La cuenta no existe.']);
        }
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data): array
    {
        return array_intersect_key($data, array_flip(['name', 'target_cents', 'target_date', 'account_id', 'icon', 'color']));
    }
}
