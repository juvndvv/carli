<?php

namespace App\Modules\Finance\Http\Requests;

final class DestroyCategoryRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'reassign_to' => $this->ownedId('categories'),
        ];
    }
}
