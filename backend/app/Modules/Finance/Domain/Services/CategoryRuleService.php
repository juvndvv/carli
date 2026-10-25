<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Support\MerchantText;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\CategoryRule;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class CategoryRuleService
{
    public function __construct(private readonly TransactionService $transactions) {}

    /**
     * @return Collection<int, CategoryRule>
     */
    public function rulesFor(User|string $user): Collection
    {
        return CategoryRule::query()->ownedBy($user)
            ->with('category')
            ->get()
            ->sortByDesc(fn (CategoryRule $rule) => strlen($rule->pattern))
            ->values();
    }

    /**
     * @param  Collection<int, CategoryRule>  $rules
     */
    public function match(Collection $rules, TransactionKind $kind, ?string $payee, ?string $description): ?CategoryRule
    {
        $texts = array_values(array_unique(array_filter([MerchantText::normalize($payee), MerchantText::normalize($description)])));

        foreach ($rules as $rule) {
            if ($rule->kind->value !== $kind->value || $rule->category->archived_at !== null) {
                continue;
            }

            foreach ($texts as $text) {
                if (MerchantText::contains($text, $rule->pattern)) {
                    return $rule;
                }
            }
        }

        return null;
    }

    /**
     * @param  array{pattern: string, category_id: string}  $data
     */
    public function create(User $user, array $data): CategoryRule
    {
        $category = $this->category($user->id, $data['category_id']);
        $pattern = $this->pattern($data['pattern']);

        $rule = CategoryRule::query()->ownedBy($user)
            ->where('kind', $category->kind->value)
            ->where('pattern', $pattern)
            ->first() ?? new CategoryRule;

        $rule->user_id = $user->id;
        $rule->pattern = $pattern;
        $rule->kind = $category->kind;
        $rule->category_id = $category->id;
        $rule->save();

        return $rule->load('category.parent');
    }

    /**
     * @param  array{pattern?: string, category_id?: string}  $data
     */
    public function update(CategoryRule $rule, array $data): CategoryRule
    {
        if (array_key_exists('category_id', $data)) {
            $category = $this->category($rule->user_id, $data['category_id']);
            $rule->category_id = $category->id;
            $rule->kind = $category->kind;
        }

        if (array_key_exists('pattern', $data)) {
            $rule->pattern = $this->pattern($data['pattern']);
        }

        $duplicate = CategoryRule::query()->ownedBy($rule->user_id)
            ->whereKeyNot($rule->id)
            ->where('kind', $rule->kind->value)
            ->where('pattern', $rule->pattern)
            ->exists();

        if ($duplicate) {
            throw ValidationException::withMessages(['pattern' => 'Ya tienes una regla con ese texto.']);
        }

        $rule->save();

        return $rule->load('category.parent');
    }

    /**
     * @return Collection<int, Transaction>
     */
    public function similar(Transaction $transaction, ?string $pattern = null): Collection
    {
        $normalizedPattern = $pattern === null ? null : MerchantText::normalize($pattern);
        $merchant = MerchantText::of($transaction->payee, $transaction->description);

        if (($normalizedPattern ?? $merchant) === '') {
            return new Collection;
        }

        return Transaction::query()->ownedBy($transaction->user_id)
            ->uncategorized()
            ->whereKeyNot($transaction->id)
            ->where('kind', $transaction->kind->value)
            ->orderByDesc('date')
            ->get()
            ->filter(function (Transaction $candidate) use ($normalizedPattern, $merchant): bool {
                if ($normalizedPattern === null) {
                    return MerchantText::of($candidate->payee, $candidate->description) === $merchant;
                }

                return MerchantText::contains(MerchantText::normalize($candidate->payee), $normalizedPattern)
                    || MerchantText::contains(MerchantText::normalize($candidate->description), $normalizedPattern);
            })
            ->values();
    }

    /**
     * @return array{updated: int, rule: CategoryRule|null}
     */
    public function applyToSimilar(Transaction $transaction, string $categoryId, bool $remember, ?string $pattern = null): array
    {
        if (! in_array($transaction->kind, [TransactionKind::Expense, TransactionKind::Income], true)) {
            throw ValidationException::withMessages(['transaction' => 'Solo se pueden categorizar gastos e ingresos.']);
        }

        $category = $this->category($transaction->user_id, $categoryId);

        if ($category->kind->value !== $transaction->kind->value) {
            throw ValidationException::withMessages(['category_id' => 'La categoría no corresponde al tipo de movimiento.']);
        }

        $rulePattern = $pattern ?? MerchantText::of($transaction->payee, $transaction->description);
        if ($remember && MerchantText::normalize($rulePattern) === '') {
            throw ValidationException::withMessages(['pattern' => 'Este movimiento no tiene un comercio que recordar.']);
        }

        return DB::transaction(function () use ($transaction, $category, $remember, $pattern, $rulePattern): array {
            $similar = $this->similar($transaction, $pattern);
            $updated = 0;

            foreach ([$transaction, ...$similar->all()] as $target) {
                if ($target->category_id === $category->id && $target->splits()->doesntExist()) {
                    continue;
                }

                $this->transactions->update($target, ['category_id' => $category->id, 'splits' => []]);
                $updated++;
            }

            $rule = $remember ? $this->create($this->owner($transaction->user_id), ['pattern' => $rulePattern, 'category_id' => $category->id]) : null;

            return ['updated' => $updated, 'rule' => $rule];
        });
    }

    private function category(string $userId, string $categoryId): Category
    {
        $category = Category::query()->ownedBy($userId)->whereKey($categoryId)->first();

        if ($category === null) {
            throw ValidationException::withMessages(['category_id' => 'La categoría no existe.']);
        }

        return $category;
    }

    private function pattern(string $pattern): string
    {
        $normalized = MerchantText::normalize($pattern);

        if (strlen($normalized) < 2) {
            throw ValidationException::withMessages(['pattern' => 'El texto de la regla debe tener al menos dos letras.']);
        }

        return $normalized;
    }

    private function owner(string $userId): User
    {
        return User::query()->findOrFail($userId);
    }
}
