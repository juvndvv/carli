<?php

namespace App\Modules\Health\Http\Requests;

use App\Modules\Health\Models\BodySite;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

final class BodySiteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('post');

        return [
            'name' => [$creating ? 'required' : 'sometimes', 'string', 'max:40'],
            'zone' => [$creating ? 'required' : 'sometimes', Rule::in(BodySite::ZONES)],
            'side' => ['sometimes', 'nullable', 'in:left,right'],
            'archived' => ['sometimes', 'boolean'],
        ];
    }
}
