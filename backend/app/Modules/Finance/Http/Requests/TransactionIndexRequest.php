<?php

namespace App\Modules\Finance\Http\Requests;

use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Queries\TransactionFilter;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

final class TransactionIndexRequest extends FinanceRequest
{
    protected function prepareForValidation(): void
    {
        foreach (['account_id', 'category_id', 'tag', 'kind'] as $key) {
            $value = $this->query($key);
            if (is_string($value)) {
                $this->merge([$key => array_values(array_filter(explode(',', $value), fn (string $item) => $item !== ''))]);
            }
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'period_id' => ['nullable', 'uuid'],
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d'],
            'account_id' => ['nullable', 'array'],
            'account_id.*' => ['uuid'],
            'category_id' => ['nullable', 'array'],
            'category_id.*' => ['string', function (string $attribute, mixed $value, \Closure $fail): void {
                if ($value !== TransactionFilter::NO_CATEGORY && (! is_string($value) || ! Str::isUuid($value))) {
                    $fail('Categoría no válida.');
                }
            }],
            'tag' => ['nullable', 'array'],
            'tag.*' => ['string', 'max:64'],
            'kind' => ['nullable', 'array'],
            'kind.*' => [Rule::enum(TransactionKind::class)],
            'min' => ['nullable', 'integer', 'min:0'],
            'max' => ['nullable', 'integer', 'min:0'],
            'q' => ['nullable', 'string', 'max:120'],
            'status' => ['nullable', Rule::enum(TransactionStatus::class)],
            'source' => ['nullable', Rule::enum(TransactionSource::class)],
            'uncategorized' => ['nullable', 'boolean'],
            'debt_id' => ['nullable', 'uuid'],
            'recurring_rule_id' => ['nullable', 'uuid'],
            'contact_id' => ['nullable', 'uuid'],
            'per_page' => ['nullable', 'integer', 'between:1,200'],
            'cursor' => ['nullable', 'string'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function filters(): array
    {
        return array_diff_key($this->validated(), array_flip(['per_page', 'cursor']));
    }
}
