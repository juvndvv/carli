<?php

namespace App\Modules\Finance\Search;

use App\Core\Search\ModuleSearcher;
use App\Core\Search\SearchResult;
use App\Models\User;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\Transaction;

final class FinanceSearcher implements ModuleSearcher
{
    public function moduleId(): string
    {
        return 'finance';
    }

    public function search(User $user, string $query, int $limit): array
    {
        $term = trim($query);
        if ($term === '') {
            return [];
        }

        $like = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term).'%';
        $results = [];

        foreach (Account::query()->ownedBy($user)->where('name', 'ILIKE', $like)->orderBy('sort_order')->limit($limit)->get() as $account) {
            $results[] = new SearchResult(
                type: 'account',
                id: $account->id,
                title: $account->name,
                url: '/finanzas/cuentas/'.$account->id,
                subtitle: Money::ofCents($account->balanceCents())->format(),
                icon: $account->icon ?? 'landmark',
            );
        }

        foreach (Contact::query()->ownedBy($user)->where('name', 'ILIKE', $like)->limit($limit)->get() as $contact) {
            $results[] = new SearchResult(
                type: 'contact',
                id: $contact->id,
                title: $contact->name,
                url: '/finanzas/compartidos/'.$contact->id,
                subtitle: 'Contacto',
                icon: 'user',
            );
        }

        $transactions = Transaction::query()->ownedBy($user)
            ->whereRaw("(coalesce(payee, '') || ' ' || coalesce(description, '')) ILIKE ?", [$like])
            ->with('category.parent')
            ->orderByDesc('date')
            ->limit($limit)
            ->get();

        foreach ($transactions as $transaction) {
            $results[] = new SearchResult(
                type: 'transaction',
                id: $transaction->id,
                title: $transaction->payee ?? $transaction->description ?? 'Movimiento',
                url: '/finanzas/movimientos?q='.rawurlencode($term),
                subtitle: Money::ofCents($transaction->amount_cents)->format().' · '.SpanishCalendar::shortDate($transaction->date)
                    .($transaction->category !== null ? ' · '.$transaction->category->name : ''),
                icon: $transaction->category->icon ?? 'receipt',
            );
        }

        return array_slice($results, 0, $limit);
    }
}
