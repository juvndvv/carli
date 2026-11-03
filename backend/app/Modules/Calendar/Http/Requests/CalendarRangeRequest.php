<?php

namespace App\Modules\Calendar\Http\Requests;

use App\Modules\Calendar\Domain\CalendarClock;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

final class CalendarRangeRequest extends FormRequest
{
    public const int MAX_DAYS = 62;

    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'from' => ['required', 'date_format:Y-m-d'],
            'to' => ['required', 'date_format:Y-m-d', 'after_or_equal:from'],
        ];
    }

    /**
     * @return list<callable(Validator): void>
     */
    public function after(): array
    {
        return [function (Validator $validator): void {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            if ($this->from()->diffInDays($this->to()) >= self::MAX_DAYS) {
                $validator->errors()->add('to', 'El rango no puede pasar de '.self::MAX_DAYS.' días.');
            }
        }];
    }

    public function from(): CarbonImmutable
    {
        return CalendarClock::date((string) $this->input('from'));
    }

    public function to(): CarbonImmutable
    {
        return CalendarClock::date((string) $this->input('to'));
    }
}
