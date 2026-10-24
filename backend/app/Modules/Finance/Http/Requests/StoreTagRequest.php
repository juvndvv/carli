<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreTagRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name' => [$required, 'string', 'max:64'],
            'color' => ['sometimes', 'nullable', 'string', 'max:32'],
        ];
    }
}
