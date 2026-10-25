<?php

namespace App\Modules\Finance\Http\Requests;

final class CategorizeSimilarRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'category_id' => ['required', 'bail', 'uuid', $this->owned('categories')],
            'remember' => ['sometimes', 'boolean'],
            'pattern' => ['sometimes', 'nullable', 'string', 'min:2', 'max:120'],
        ];
    }
}
