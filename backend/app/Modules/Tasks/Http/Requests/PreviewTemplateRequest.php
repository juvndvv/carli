<?php

namespace App\Modules\Tasks\Http\Requests;

final class PreviewTemplateRequest extends StoreTemplateRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return $this->frequencyRules(true);
    }
}
