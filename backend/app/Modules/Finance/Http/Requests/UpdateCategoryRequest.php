<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\CategoryKind;
use Illuminate\Validation\Rule;

final class UpdateCategoryRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:80'],
            'kind' => ['sometimes', Rule::enum(CategoryKind::class)],
            'parent_id' => ['sometimes', ...$this->ownedId('categories')],
            'icon' => ['sometimes', 'nullable', 'string', 'max:64'],
            'color' => ['sometimes', 'nullable', 'string', 'max:32'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'opens_period' => ['sometimes', 'boolean'],
            'archived' => ['sometimes', 'boolean'],
        ];
    }
}
