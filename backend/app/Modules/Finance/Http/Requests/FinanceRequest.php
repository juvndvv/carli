<?php

namespace App\Modules\Finance\Http\Requests;

use App\Models\User;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\Tag;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Exists;

abstract class FinanceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    private const array MODELS = [
        'accounts' => Account::class,
        'categories' => Category::class,
        'contacts' => Contact::class,
        'debts' => Debt::class,
        'periods' => Period::class,
        'tags' => Tag::class,
        'transactions' => Transaction::class,
    ];

    protected function owned(string $table): Exists
    {
        return Rule::exists(self::MODELS[$table], 'id')->where('user_id', $this->financeUser()->id);
    }

    public function financeUser(): User
    {
        $user = $this->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }

    /**
     * @return list<mixed>
     */
    protected function ownedId(string $table, bool $required = false): array
    {
        return [$required ? 'required' : 'nullable', 'bail', 'uuid', $this->owned($table)];
    }

    /**
     * @return list<string>
     */
    protected function money(bool $required = true): array
    {
        return [$required ? 'required' : 'sometimes', 'integer', 'between:-100000000000,100000000000'];
    }
}
