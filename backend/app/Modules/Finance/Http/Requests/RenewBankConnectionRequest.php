<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\BankSync\Data\BankReturnTarget;
use Illuminate\Validation\Rule;

final class RenewBankConnectionRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'return_to' => ['sometimes', Rule::enum(BankReturnTarget::class)],
        ];
    }

    public function returnTarget(): BankReturnTarget
    {
        return BankReturnTarget::tryFrom((string) $this->validated('return_to', BankReturnTarget::Web->value)) ?? BankReturnTarget::Web;
    }
}
