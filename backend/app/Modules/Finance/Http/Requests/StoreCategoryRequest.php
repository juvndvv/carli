<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\CategoryKind;
use Illuminate\Validation\Rule;

class StoreCategoryRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:80'],
            'kind' => ['required_without:parent_id', Rule::enum(CategoryKind::class)],
            'parent_id' => ['sometimes', ...$this->ownedId('categories')],
            'icon' => ['nullable', 'string', 'max:64'],
            'color' => ['nullable', 'string', 'max:32'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'opens_period' => ['sometimes', 'boolean'],
        ];
    }
}
