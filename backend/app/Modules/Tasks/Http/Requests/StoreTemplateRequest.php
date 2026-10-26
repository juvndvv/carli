<?php

namespace App\Modules\Tasks\Http\Requests;

use App\Core\Recurrence\RecurrenceRule;
use App\Modules\Tasks\Domain\Enums\TemplatePolicy;
use Closure;
use Illuminate\Validation\Rule;

class StoreTemplateRequest extends TasksRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('POST');

        return [
            'title' => [$creating ? 'required' : 'sometimes', 'string', 'max:255'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:10000'],
            'list_id' => $this->ownedList(),
            'subtasks' => ['sometimes', 'array', 'max:50'],
            'subtasks.*' => ['string', 'max:255'],
            'due_time' => $this->time(),
            'important' => ['sometimes', 'boolean'],
            'policy' => ['sometimes', Rule::enum(TemplatePolicy::class)],
            'lead_days' => ['sometimes', 'integer', 'between:0,365'],
            'apply_to_open' => $creating ? ['prohibited'] : ['sometimes', 'boolean'],
            ...$this->frequencyRules($creating),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    protected function frequencyRules(bool $required): array
    {
        $presence = $required ? 'required_without:after_done_interval_days' : 'sometimes';

        return [
            'rrule' => [$presence, 'nullable', 'string', 'max:255', 'prohibits:after_done_interval_days', function (string $attribute, mixed $value, Closure $fail): void {
                if (is_string($value) && ! RecurrenceRule::isValid($value)) {
                    $fail('La frecuencia no es válida.');
                }
            }],
            'after_done_interval_days' => [$required ? 'required_without:rrule' : 'sometimes', 'nullable', 'integer', 'between:1,3650'],
            'dtstart' => ['sometimes', 'date_format:Y-m-d'],
            'until' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'prohibits:count'],
            'count' => ['sometimes', 'nullable', 'integer', 'between:1,10000'],
        ];
    }
}
