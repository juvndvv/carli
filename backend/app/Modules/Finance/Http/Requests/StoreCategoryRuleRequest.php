<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreCategoryRuleRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'pattern' => [$required, 'string', 'min:2', 'max:120'],
            'category_id' => [$required, 'bail', 'uuid', $this->owned('categories')],
        ];
    }
}
