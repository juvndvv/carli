<?php

namespace App\Core\Http\Requests;

use App\Core\Notifications\NotificationPreferenceService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class UpdateNotificationPreferencesRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'preferences' => ['required', 'array', 'max:200'],
            'preferences.*.module' => ['required', 'string', 'max:64'],
            'preferences.*.type' => ['required', 'string', 'max:64'],
            'preferences.*.push' => ['required', 'boolean'],
            'preferences.*.in_app' => ['required', 'boolean'],
        ];
    }

    /**
     * @return list<callable(Validator): void>
     */
    public function after(NotificationPreferenceService $preferences): array
    {
        return [
            function (Validator $validator) use ($preferences): void {
                foreach ((array) $this->input('preferences', []) as $index => $preference) {
                    $module = is_array($preference) ? ($preference['module'] ?? null) : null;
                    $type = is_array($preference) ? ($preference['type'] ?? null) : null;

                    if (is_string($module) && is_string($type) && ! $preferences->isKnownType($module, $type)) {
                        $validator->errors()->add("preferences.{$index}.type", 'El tipo de notificación no existe.');
                    }
                }
            },
        ];
    }

    /**
     * @return list<array{module: string, type: string, push: bool, in_app: bool}>
     */
    public function preferences(): array
    {
        $preferences = [];

        foreach ((array) $this->validated('preferences') as $preference) {
            $preferences[] = [
                'module' => (string) $preference['module'],
                'type' => (string) $preference['type'],
                'push' => (bool) $preference['push'],
                'in_app' => (bool) $preference['in_app'],
            ];
        }

        return $preferences;
    }
}
