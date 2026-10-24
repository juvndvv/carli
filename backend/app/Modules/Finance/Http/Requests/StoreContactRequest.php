<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreContactRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name' => [$required, 'string', 'max:120'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'archived' => ['sometimes', 'boolean'],
        ];
    }
}
