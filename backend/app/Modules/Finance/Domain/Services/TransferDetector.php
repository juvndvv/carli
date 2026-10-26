<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\TransferSource;
use App\Modules\Finance\Domain\Support\MerchantText;
use App\Modules\Finance\Domain\Support\TransferCandidate;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class TransferDetector
{
    public const int MAX_DAYS_APART = 3;

    public const int SYNC_WINDOW_DAYS = 30;

    public const string SIGNAL_IBAN = 'iban';

    public const string SIGNAL_HOLDER = 'holder';

    public const string SIGNAL_CONCEPT = 'concept';

    private const array OWN_TRANSFER_WORDS = ['TOP UP', 'TOPUP', 'RECARGA', 'TRASPASO', 'CUENTA PROPIA', 'CUENTAS PROPIAS', 'ENTRE CUENTAS', 'MISMO TITULAR'];

    private const int MIN_NAME_TOKENS = 2;

    private const int IBAN_EDGE = 4;

    public function __construct(private readonly TransferConversionService $conversions) {}

    /**
     * @return array{converted: list<TransferCandidate>, suggested: list<TransferCandidate>}
     */
    public function detect(User|string $user, ?CarbonImmutable $since = null, bool $dryRun = false): array
    {
        $converted = [];
        $suggested = [];

        foreach ($this->candidates($user) as $candidate) {
            if (! $candidate->isAutoConvertible() || ($since !== null && $candidate->latestDate()->lessThan($since))) {
                $suggested[] = $candidate;

                continue;
            }

            if (! $dryRun) {
                $this->conversions->convert($candidate->outgoing, $candidate->incoming, TransferSource::Auto);
            }

            $converted[] = $candidate;
        }

        return ['converted' => $converted, 'suggested' => $suggested];
    }

    /**
     * @return list<TransferCandidate>
     */
    public function candidates(User|string $user): array
    {
        $userId = $user instanceof User ? $user->id : $user;
        $pairs = $this->pairs($userId);

        if ($pairs === []) {
            return [];
        }

        $ids = array_unique(array_merge(array_column($pairs, 'outgoing_id'), array_column($pairs, 'incoming_id')));
        $transactions = Transaction::query()->ownedBy($userId)->with('account.bankConnection')->whereIn('id', $ids)->get()->keyBy('id');
        $userName = User::query()->whereKey($userId)->value('name');
        $outgoingCount = array_count_values(array_column($pairs, 'outgoing_id'));
        $incomingCount = array_count_values(array_column($pairs, 'incoming_id'));

        $candidates = [];
        foreach ($pairs as $pair) {
            $outgoing = $transactions->get($pair['outgoing_id']);
            $incoming = $transactions->get($pair['incoming_id']);

            if ($outgoing === null || $incoming === null) {
                continue;
            }

            $candidates[] = new TransferCandidate(
                $outgoing,
                $incoming,
                $this->signals($outgoing, $incoming, is_string($userName) ? $userName : null),
                $outgoingCount[$pair['outgoing_id']] === 1 && $incomingCount[$pair['incoming_id']] === 1,
            );
        }

        usort($candidates, fn (TransferCandidate $a, TransferCandidate $b) => [$b->isClear(), count($b->signals), $a->daysApart(), $b->latestDate()->toDateString(), $a->key()]
            <=> [$a->isClear(), count($a->signals), $b->daysApart(), $a->latestDate()->toDateString(), $b->key()]);

        $used = [];
        $selected = [];
        foreach ($candidates as $candidate) {
            if (isset($used[$candidate->outgoing->id]) || isset($used[$candidate->incoming->id])) {
                continue;
            }

            $used[$candidate->outgoing->id] = $used[$candidate->incoming->id] = true;
            $selected[] = $candidate;
        }

        return $selected;
    }

    /**
     * @return list<array{outgoing_id: string, incoming_id: string}>
     */
    private function pairs(string $userId): array
    {
        $eligible = fn (string $alias): string => <<<SQL
            {$alias}.deleted_at IS NULL
            AND {$alias}.source = 'bank'
            AND {$alias}.status = 'cleared'
            AND {$alias}.transfer_group_id IS NULL
            AND {$alias}.debt_id IS NULL
            AND {$alias}.recurring_rule_id IS NULL
            AND NOT EXISTS (SELECT 1 FROM finance.transaction_splits s WHERE s.transaction_id = {$alias}.id)
            AND NOT EXISTS (SELECT 1 FROM finance.shared_expense_shares sh WHERE sh.transaction_id = {$alias}.id OR sh.settlement_transaction_id = {$alias}.id)
            SQL;

        /** @var list<object{outgoing_id: string, incoming_id: string}> $rows */
        $rows = DB::select(<<<SQL
            SELECT o.id AS outgoing_id, i.id AS incoming_id
            FROM finance.transactions o
            JOIN finance.transactions i
              ON i.user_id = o.user_id
             AND i.amount_cents = -o.amount_cents
             AND i.account_id <> o.account_id
             AND abs(i.date - o.date) <= ?
            WHERE o.user_id = ?
              AND o.kind = 'expense' AND o.amount_cents < 0
              AND i.kind = 'income'
              AND {$eligible('o')}
              AND {$eligible('i')}
              AND NOT EXISTS (
                SELECT 1 FROM finance.transfer_exclusions x
                WHERE x.outgoing_transaction_id = o.id AND x.incoming_transaction_id = i.id
              )
            ORDER BY o.date DESC, o.id, i.id
            SQL, [self::MAX_DAYS_APART, $userId]);

        return array_map(fn (object $row) => ['outgoing_id' => (string) $row->outgoing_id, 'incoming_id' => (string) $row->incoming_id], $rows);
    }

    /**
     * @return list<string>
     */
    private function signals(Transaction $outgoing, Transaction $incoming, ?string $userName): array
    {
        $signals = [];

        if ($this->ibanMatches($outgoing, 'creditor_account', $incoming->account) || $this->ibanMatches($incoming, 'debtor_account', $outgoing->account)) {
            $signals[] = self::SIGNAL_IBAN;
        }

        $holders = array_filter([
            $userName,
            $this->partyName($outgoing, 'debtor'),
            $this->partyName($incoming, 'creditor'),
        ]);
        $counterparties = array_filter([
            $this->partyName($outgoing, 'creditor') ?? $outgoing->payee,
            $this->partyName($incoming, 'debtor') ?? $incoming->payee,
        ]);

        foreach ($counterparties as $counterparty) {
            foreach ($holders as $holder) {
                if (self::sameHolder($counterparty, $holder)) {
                    $signals[] = self::SIGNAL_HOLDER;

                    break 2;
                }
            }
        }

        if ($this->mentionsOwnTransfer($outgoing, $incoming->account) || $this->mentionsOwnTransfer($incoming, $outgoing->account)) {
            $signals[] = self::SIGNAL_CONCEPT;
        }

        return $signals;
    }

    public static function sameHolder(string $a, string $b): bool
    {
        $left = self::nameTokens($a);
        $right = self::nameTokens($b);
        [$shorter, $longer] = count($left) <= count($right) ? [$left, $right] : [$right, $left];

        return count($shorter) >= self::MIN_NAME_TOKENS && array_diff($shorter, $longer) === [];
    }

    /**
     * @return list<string>
     */
    private static function nameTokens(string $name): array
    {
        $tokens = explode(' ', MerchantText::normalize($name));

        return array_values(array_unique(array_filter($tokens, fn (string $token) => strlen($token) >= 2)));
    }

    public static function ibanMatchesMasked(string $identifier, string $masked): bool
    {
        $stored = preg_replace('/[^A-Z0-9]/', '', strtoupper($masked)) ?? '';
        $raw = preg_replace('/\s+/', '', strtoupper($identifier)) ?? '';

        if (strlen($stored) < self::IBAN_EDGE * 2 || strlen($raw) < self::IBAN_EDGE * 2) {
            return false;
        }

        if (substr($raw, -self::IBAN_EDGE) !== substr($stored, -self::IBAN_EDGE)) {
            return false;
        }

        $hidden = preg_match('/[^A-Z0-9]/', $raw) === 1;
        $prefix = $hidden ? 2 : self::IBAN_EDGE;

        return substr($raw, 0, $prefix) === substr($stored, 0, $prefix);
    }

    private function ibanMatches(Transaction $transaction, string $party, Account $other): bool
    {
        $masked = $this->maskedIban($other);
        if ($masked === null) {
            return false;
        }

        $account = $transaction->raw[$party] ?? null;
        if (! is_array($account)) {
            return false;
        }

        $scheme = is_array($account['other'] ?? null) ? $account['other'] : [];
        foreach ([$account['iban'] ?? null, $account['bban'] ?? null, $scheme['identification'] ?? null] as $identifier) {
            if (is_string($identifier) && self::ibanMatchesMasked($identifier, $masked)) {
                return true;
            }
        }

        return false;
    }

    private function maskedIban(Account $account): ?string
    {
        if (! $account->isBankLinked()) {
            return null;
        }

        $iban = $account->bankConnection?->bankAccount((string) $account->external_account_uid)['iban'] ?? null;

        return is_string($iban) && $iban !== '' ? $iban : null;
    }

    private function partyName(Transaction $transaction, string $party): ?string
    {
        $data = $transaction->raw[$party] ?? null;
        $name = is_array($data) ? ($data['name'] ?? null) : null;

        return is_string($name) && trim($name) !== '' ? $name : null;
    }

    private function mentionsOwnTransfer(Transaction $transaction, Account $other): bool
    {
        $code = $transaction->raw['bank_transaction_code'] ?? null;
        $text = MerchantText::normalize(implode(' ', array_filter([
            $transaction->payee,
            $transaction->description,
            is_array($code) && is_string($code['code'] ?? null) ? $code['code'] : null,
        ])));

        $words = self::OWN_TRANSFER_WORDS;
        $ownBank = MerchantText::normalize($transaction->account->bankConnection?->aspsp_name);
        $otherBank = MerchantText::normalize($other->bankConnection?->aspsp_name);
        if ($otherBank !== '' && $otherBank !== $ownBank) {
            $words[] = $otherBank;
        }

        foreach ($words as $word) {
            if (MerchantText::contains($text, $word)) {
                return true;
            }
        }

        return false;
    }
}
