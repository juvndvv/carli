<?php

namespace App\Modules\Finance\Domain\Services;

use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Support\MerchantText;
use App\Modules\Finance\Domain\Support\RecurringMatch;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;

final class RecurringBankMatcher
{
    public const int WINDOW_DAYS = 5;

    private const int AMOUNT_TOLERANCE_PERCENT = 50;

    public function __construct(private readonly TransactionService $transactions) {}

    public function match(Account $account, TransactionKind $kind, int $amountCents, CarbonImmutable $date, ?string $payee, ?string $description): ?RecurringMatch
    {
        $text = MerchantText::normalize(trim(($payee ?? '').' '.($description ?? '')));
        $from = $date->subDays(self::WINDOW_DAYS)->toDateString();
        $until = $date->addDays(self::WINDOW_DAYS)->toDateString();
        $best = null;

        $expected = Transaction::query()->withoutGlobalScopes()
            ->whereNull('deleted_at')
            ->where('account_id', $account->id)
            ->where('kind', $kind->value)
            ->where('source', TransactionSource::Recurring->value)
            ->where('status', TransactionStatus::Pending->value)
            ->whereBetween('recurring_date', [$from, $until])
            ->with('recurringRule')
            ->get();

        foreach ($expected as $transaction) {
            if ($transaction->recurringRule instanceof RecurringRule && $transaction->recurring_date !== null) {
                $best = $this->better($best, $this->candidate($transaction->recurringRule, $transaction->recurring_date, $transaction, $transaction->amount_cents, $text, $amountCents, $date));
            }
        }

        $upcoming = RecurringRule::query()->withoutGlobalScopes()
            ->where('account_id', $account->id)
            ->where('kind', $kind->value)
            ->whereNull('cancelled_at')
            ->whereBetween('next_occurrence', [$from, $until])
            ->get();

        foreach ($upcoming as $rule) {
            if ($rule->next_occurrence !== null) {
                $best = $this->better($best, $this->candidate($rule, $rule->next_occurrence, null, $rule->amount_cents, $text, $amountCents, $date));
            }
        }

        return $best;
    }

    /**
     * @param  array<string, mixed>  $raw
     */
    public function absorb(RecurringMatch $match, Account $account, string $externalId, int $amountCents, CarbonImmutable $date, ?string $payee, ?string $description, array $raw): Transaction
    {
        $changes = [
            'amount_cents' => $amountCents,
            'date' => $date->toDateString(),
            'status' => TransactionStatus::Cleared->value,
            'description' => $description,
        ];

        if ($match->expected !== null) {
            $transaction = $match->expected;
            $transaction->source = TransactionSource::Bank;
            $transaction->external_id = $externalId;
            $transaction->raw = $raw;

            return $this->transactions->update($transaction, $changes + ['payee' => $transaction->payee ?? $payee]);
        }

        $rule = RecurringRule::query()->withoutGlobalScopes()->whereKey($match->rule->id)->lockForUpdate()->firstOrFail();

        $transaction = $this->transactions->create($account->user_id, $changes + [
            'account_id' => $account->id,
            'kind' => $rule->kind->value,
            'payee' => $rule->payee ?? $payee,
            'category_id' => $rule->category_id,
            'debt_id' => $rule->debt()->value('id'),
        ], $rule->id, $match->occurrence->toDateString(), TransactionSource::Bank);

        $transaction->forceFill(['external_id' => $externalId, 'raw' => $raw])->save();

        $rule->next_occurrence = RecurringService::schedule($rule)->after($match->occurrence);
        $rule->save();

        return $transaction;
    }

    private function candidate(RecurringRule $rule, CarbonImmutable $occurrence, ?Transaction $expected, int $expectedCents, string $text, int $amountCents, CarbonImmutable $date): ?RecurringMatch
    {
        $merchantMatched = MerchantText::contains($text, MerchantText::normalize($rule->payee ?? $rule->description));
        $gap = abs($amountCents - $expectedCents);
        $withinTolerance = $gap * 100 <= abs($expectedCents) * self::AMOUNT_TOLERANCE_PERCENT;

        if ($gap !== 0 && ! ($merchantMatched && $withinTolerance)) {
            return null;
        }

        return new RecurringMatch($rule, $occurrence, $expected, $merchantMatched, $gap, (int) abs($occurrence->diffInDays($date, false)));
    }

    private function better(?RecurringMatch $current, ?RecurringMatch $candidate): ?RecurringMatch
    {
        if ($candidate === null) {
            return $current;
        }

        return $current === null || $candidate->isCloserThan($current) ? $candidate : $current;
    }
}
