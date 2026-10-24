<?php

namespace App\Modules\Finance\Http\Requests;

final class MergeTagRequest extends FinanceRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'into_tag_id' => $this->ownedId('tags', required: true),
        ];
    }
}
