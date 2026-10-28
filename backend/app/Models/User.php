<?php

namespace App\Models;

use App\Core\Models\NotificationPreference;
use App\Core\Models\PushDevice;
use App\Core\Models\UserModule;
use App\Core\Push\PushDeviceKind;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Laravel\Fortify\TwoFactorAuthenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * @property string $id
 * @property string $name
 * @property string $email
 * @property string $password
 * @property string|null $two_factor_secret
 * @property string|null $two_factor_recovery_codes
 * @property Carbon|null $two_factor_confirmed_at
 * @property array<string, mixed> $preferences
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable(['name', 'email', 'password', 'preferences'])]
#[Hidden(['password', 'remember_token', 'two_factor_secret', 'two_factor_recovery_codes'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasUuids, Notifiable, TwoFactorAuthenticatable;

    public const array DEFAULT_PREFERENCES = [
        'theme' => 'system',
        'sidebar_collapsed' => false,
    ];

    protected $attributes = [
        'preferences' => '{}',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'two_factor_confirmed_at' => 'datetime',
            'password' => 'hashed',
            'preferences' => 'array',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function resolvedPreferences(): array
    {
        return array_merge(self::DEFAULT_PREFERENCES, $this->preferences ?? []);
    }

    /**
     * @return HasMany<UserModule, $this>
     */
    public function moduleSettings(): HasMany
    {
        return $this->hasMany(UserModule::class);
    }

    /**
     * The app's own tokens, which receive alerts.
     *
     * @return HasMany<PushDevice, $this>
     */
    public function pushDevices(): HasMany
    {
        return $this->hasMany(PushDevice::class)->where('kind', PushDeviceKind::App->value);
    }

    /**
     * Widget tokens, which only receive silent reloads.
     *
     * @return HasMany<PushDevice, $this>
     */
    public function widgetPushDevices(): HasMany
    {
        return $this->hasMany(PushDevice::class)->where('kind', PushDeviceKind::Widgets->value);
    }

    /**
     * @return HasMany<NotificationPreference, $this>
     */
    public function notificationPreferences(): HasMany
    {
        return $this->hasMany(NotificationPreference::class);
    }
}
