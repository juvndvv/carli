<?php

namespace App\Modules\Finance\Pending;

use App\Core\Pending\PendingItem;
use App\Core\Pending\PendingItemsProvider;
use App\Core\Pending\PendingPage;
use App\Models\User;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Services\RecurringBankMatcher;
use App\Modules\Finance\Domain\Services\TransferDetector;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Domain\Support\TransferCandidate;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Queries\TransactionCursor;
use Illuminate\Database\Eloquent\Builder;

final class FinancePendingItems implements PendingItemsProvider
{
    public const string MODULE = 'finance';

    public const string UNCATEGORIZED = 'uncategorized_transaction';

    public const string RECURRING = 'recurring_to_confirm';

    public const string TRANSFER_SUGGESTION = 'transfer_suggestion';

    public const string UNCATEGORIZED_ROUTE = '/finanzas/movimientos?sin_categoria=1&periodo=todos';

    public const string RECURRING_ROUTE = '/finanzas/recurrentes';

    public const string TRANSFER_SUGGESTION_ROUTE = '/finanzas/movimientos?periodo=todos';

    private const int PAGE_SIZE = 50;

    /** @var array<string, list<TransferCandidate>> */
    private array $suggestions = [];

    public function __construct(private readonly TransferDetector $detector) {}

    public function moduleId(): string
    {
        return self::MODULE;
    }

    public function counts(User $user): array
    {
        return [
            self::TRANSFER_SUGGESTION => count($this->suggestionsFor($user)),
            self::UNCATEGORIZED => $this->uncategorized($user)->count(),
            self::RECURRING => $this->recurring($user)->count(),
        ];
    }

    public function items(User $user, ?string $type, ?string $cursor): PendingPage
    {
        $segments = [
            self::TRANSFER_SUGGESTION => fn (?string $inner) => $this->suggestionPage($user),
            self::UNCATEGORIZED => fn (?string $inner) => $this->uncategorizedPage($user, $inner),
            self::RECURRING => fn (?string $inner) => $this->recurringPage($user, $inner),
        ];

        if ($type !== null) {
            $segments = array_intersect_key($segments, [$type => true]);
        }

        return PendingPage::chain($segments, $cursor);
    }

    public function describe(string $type, int $count): string
    {
        return match ($type) {
            self::UNCATEGORIZED => $count === 1 ? '1 movimiento por categorizar' : "{$count} movimientos por categorizar",
            self::RECURRING => $count === 1 ? '1 recurrente por confirmar' : "{$count} recurrentes por confirmar",
            self::TRANSFER_SUGGESTION => $count === 1 ? '1 posible transferencia por revisar' : "{$count} posibles transferencias por revisar",
            default => $count === 1 ? '1 pendiente' : "{$count} pendientes",
        };
    }

    /**
     * @return Builder<Transaction>
     */
    private function uncategorized(User $user): Builder
    {
        $suggested = [];
        foreach ($this->suggestionsFor($user) as $candidate) {
            $suggested[] = $candidate->outgoing->id;
            $suggested[] = $candidate->incoming->id;
        }

        return Transaction::query()->ownedBy($user)->uncategorized()
            ->when($suggested !== [], fn (Builder $query) => $query->whereNotIn('id', $suggested));
    }

    /**
     * @return list<TransferCandidate>
     */
    private function suggestionsFor(User $user): array
    {
        return $this->suggestions[$user->id] ??= $this->detector->candidates($user);
    }

    private function suggestionPage(User $user): PendingPage
    {
        return new PendingPage(array_map(function (TransferCandidate $candidate): PendingItem {
            $from = $candidate->outgoing->account;
            $to = $candidate->incoming->account;
            [$fromLabel, $toLabel] = $this->labels($from, $to);

            return new PendingItem(
                module: self::MODULE,
                type: self::TRANSFER_SUGGESTION,
                id: $candidate->outgoing->id,
                title: "¿Es una transferencia entre {$fromLabel} y {$toLabel}?",
                date: $candidate->latestDate()->toDateString(),
                route: self::TRANSFER_SUGGESTION_ROUTE,
                subtitle: "{$fromLabel} → {$toLabel}",
                amountCents: -$candidate->outgoing->amount_cents,
                meta: [
                    'outgoing_transaction_id' => $candidate->outgoing->id,
                    'incoming_transaction_id' => $candidate->incoming->id,
                    'from_account' => ['id' => $from->id, 'name' => $from->name],
                    'to_account' => ['id' => $to->id, 'name' => $to->name],
                    'outgoing_date' => $candidate->outgoing->date->toDateString(),
                    'incoming_date' => $candidate->incoming->date->toDateString(),
                    'outgoing_text' => $candidate->outgoing->payee ?? $candidate->outgoing->description,
                    'incoming_text' => $candidate->incoming->payee ?? $candidate->incoming->description,
                    'signals' => $candidate->signals,
                    'unique' => $candidate->unique,
                ],
            );
        }, $this->suggestionsFor($user)));
    }

    /**
     * @return array{string, string}
     */
    private function labels(Account $from, Account $to): array
    {
        $fromBank = $from->bankConnection?->aspsp_name;
        $toBank = $to->bankConnection?->aspsp_name;

        if ($fromBank !== null && $toBank !== null && $fromBank !== $toBank) {
            return [$fromBank, $toBank];
        }

        return [$from->name, $to->name];
    }

    /**
     * @return Builder<Transaction>
     */
    private function recurring(User $user): Builder
    {
        $graceStart = SpanishCalendar::today()->subDays(RecurringBankMatcher::WINDOW_DAYS)->toDateString();

        return Transaction::query()->ownedBy($user)
            ->whereNotNull('recurring_rule_id')
            ->where('status', TransactionStatus::Pending->value)
            ->where(fn (Builder $query) => $query
                ->where('date', '<', $graceStart)
                ->orWhereNotIn('account_id', Account::query()->withoutGlobalScopes()->whereNotNull('bank_connection_id')->whereNotNull('external_account_uid')->select('id')));
    }

    private function uncategorizedPage(User $user, ?string $cursor): PendingPage
    {
        $query = $this->uncategorized($user)->with('account');
        $position = TransactionCursor::decode($cursor);

        if ($position !== null) {
            $query->whereRaw('(date, id) < (?::date, ?::uuid)', [$position['date'], $position['id']]);
        }

        $rows = $query->orderByDesc('date')->orderByDesc('id')->limit(self::PAGE_SIZE + 1)->get();

        return $this->paginate(array_values($rows->all()), fn (Transaction $transaction) => new PendingItem(
            module: self::MODULE,
            type: self::UNCATEGORIZED,
            id: $transaction->id,
            title: $transaction->payee ?? $transaction->description ?? 'Movimiento',
            date: $transaction->date->toDateString(),
            route: self::UNCATEGORIZED_ROUTE,
            subtitle: $transaction->account->name.($transaction->source === TransactionSource::Bank ? ' · Importado del banco' : ''),
            amountCents: $transaction->amount_cents,
            meta: [
                'transaction_id' => $transaction->id,
                'kind' => $transaction->kind->value,
                'account_id' => $transaction->account_id,
                'source' => $transaction->source->value,
                'payee' => $transaction->payee,
                'description' => $transaction->description,
            ],
        ));
    }

    private function recurringPage(User $user, ?string $cursor): PendingPage
    {
        $query = $this->recurring($user)->with(['account', 'recurringRule']);
        $position = TransactionCursor::decode($cursor);

        if ($position !== null) {
            $query->whereRaw('(date, id) > (?::date, ?::uuid)', [$position['date'], $position['id']]);
        }

        $rows = $query->orderBy('date')->orderBy('id')->limit(self::PAGE_SIZE + 1)->get();

        return $this->paginate(array_values($rows->all()), fn (Transaction $transaction) => new PendingItem(
            module: self::MODULE,
            type: self::RECURRING,
            id: $transaction->id,
            title: $transaction->recurringRule?->displayName() ?? $transaction->payee ?? $transaction->description ?? 'Recurrente',
            date: $transaction->date->toDateString(),
            route: self::RECURRING_ROUTE,
            subtitle: $transaction->account->name.($transaction->account->isBankLinked() ? ' · No ha entrado en el banco' : ' · Por confirmar'),
            amountCents: $transaction->amount_cents,
            meta: [
                'transaction_id' => $transaction->id,
                'rule_id' => $transaction->recurring_rule_id,
                'kind' => $transaction->kind->value,
                'account_id' => $transaction->account_id,
                'category_id' => $transaction->category_id,
            ],
        ));
    }

    /**
     * @param  list<Transaction>  $rows
     * @param  callable(Transaction): PendingItem  $present
     */
    private function paginate(array $rows, callable $present): PendingPage
    {
        $page = array_slice($rows, 0, self::PAGE_SIZE);
        $last = end($page);

        return new PendingPage(
            array_map($present, $page),
            count($rows) > self::PAGE_SIZE && $last !== false ? TransactionCursor::encode($last) : null,
        );
    }
}
