<?php

namespace App\Modules\Finance\Http\Requests;

final class StoreBankConnectionRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'aspsp_name' => ['required', 'string', 'max:120'],
            'aspsp_country' => ['required', 'string', 'size:2', 'alpha'],
        ];
    }
}
