<?php

namespace App\Modules\Finance\Http\Requests;

final class BankAspspsRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'country' => ['sometimes', 'string', 'size:2', 'alpha'],
        ];
    }

    public function country(): string
    {
        $configured = config('services.enable_banking.country');

        return strtoupper((string) $this->validated('country', is_string($configured) ? $configured : 'ES'));
    }
}
