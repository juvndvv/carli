<?php

namespace App\Modules\Finance\Queries;

use App\Modules\Finance\Http\Resources\CategorySummary;
use App\Modules\Finance\Models\Category;
use Illuminate\Support\Facades\DB;

final class PayeeSuggestions
{
    /**
     * @return list<array{payee: string, count: int, last_date: string, last_amount_cents: int, kind: string, category: array<string, mixed>|null}>
     */
    public function suggest(string $userId, string $query, ?string $kind, int $limit): array
    {
        $term = trim($query);
        $like = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term).'%';

        $payees = DB::table('finance.transactions')
            ->where('user_id', $userId)
            ->whereNull('deleted_at')
            ->whereNotNull('payee')
            ->whereIn('kind', $kind === null ? ['expense', 'income'] : [$kind])
            ->when($term !== '', fn ($builder) => $builder->where('payee', 'ILIKE', $like))
            ->groupBy('payee')
            ->selectRaw('payee, count(*) AS uses, max(date) AS last_date')
            ->orderByRaw($term === '' ? 'max(date) DESC' : 'CASE WHEN payee ILIKE ? THEN 0 ELSE 1 END, count(*) DESC, max(date) DESC', $term === '' ? [] : [str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term).'%'])
            ->limit($limit)
            ->get();

        $suggestions = [];
        foreach ($payees as $row) {
            $latest = DB::table('finance.transactions')
                ->where('user_id', $userId)
                ->whereNull('deleted_at')
                ->where('payee', $row->payee)
                ->whereIn('kind', ['expense', 'income'])
                ->orderByDesc('date')
                ->orderByDesc('created_at')
                ->first(['amount_cents', 'kind']);

            $categoryId = DB::table('finance.transactions')
                ->where('user_id', $userId)
                ->whereNull('deleted_at')
                ->where('payee', $row->payee)
                ->whereNotNull('category_id')
                ->groupBy('category_id')
                ->orderByRaw('count(*) DESC, max(date) DESC')
                ->value('category_id');

            $category = is_string($categoryId)
                ? Category::query()->ownedBy($userId)->with('parent')->find($categoryId)
                : null;

            $suggestions[] = [
                'payee' => (string) $row->payee,
                'count' => (int) $row->uses,
                'last_date' => (string) $row->last_date,
                'last_amount_cents' => (int) ($latest->amount_cents ?? 0),
                'kind' => (string) ($latest->kind ?? 'expense'),
                'category' => CategorySummary::of($category),
            ];
        }

        return $suggestions;
    }

    /**
     * @return array{category: array<string, mixed>|null, source: string|null}
     */
    public function suggestCategory(string $userId, ?string $payee, ?string $description, ?string $kind): array
    {
        $candidates = [
            'payee' => ['column' => 'payee', 'value' => trim((string) $payee)],
            'description' => ['column' => 'description', 'value' => trim((string) $description)],
        ];

        foreach ($candidates as $source => $candidate) {
            if ($candidate['value'] === '') {
                continue;
            }

            $categoryId = $this->mostUsedCategory($userId, $candidate['column'], $candidate['value'], $kind);
            $category = $categoryId === null ? null : Category::query()->ownedBy($userId)->with('parent')->whereNull('archived_at')->find($categoryId);

            if ($category !== null) {
                return ['category' => CategorySummary::of($category), 'source' => $source];
            }
        }

        return ['category' => null, 'source' => null];
    }

    /**
     * @param  'payee'|'description'  $column
     */
    private function mostUsedCategory(string $userId, string $column, string $value, ?string $kind): ?string
    {
        $categoryId = DB::table('finance.transactions')
            ->where('user_id', $userId)
            ->whereNull('deleted_at')
            ->whereNotNull('category_id')
            ->whereIn('kind', $kind === null ? ['expense', 'income'] : [$kind])
            ->whereRaw($column === 'payee' ? 'lower(trim(payee)) = lower(?)' : 'lower(trim(description)) = lower(?)', [$value])
            ->groupBy('category_id')
            ->orderByRaw('count(*) DESC, max(date) DESC')
            ->value('category_id');

        return is_string($categoryId) ? $categoryId : null;
    }
}
