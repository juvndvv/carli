<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\BankSync\Data\BankReturnTarget;
use Illuminate\Validation\Rule;

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
            'return_to' => ['sometimes', Rule::enum(BankReturnTarget::class)],
        ];
    }

    public function returnTarget(): BankReturnTarget
    {
        return BankReturnTarget::tryFrom((string) $this->validated('return_to', BankReturnTarget::Web->value)) ?? BankReturnTarget::Web;
    }
}
