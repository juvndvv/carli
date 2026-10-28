<?php

use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Notifications\WeighReminder;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Notification;

/** The 06:51 weigh-in from 2026-10-28 as the scale reported it (see ScaleProtocolTests on iOS). */
const HEALTH_IMPEDANCES = [2920, 2539, 2879, 2502, 2450, 2061, 2336, 1978, 212, 202, 2897, 2552, 2794, 2478, 2487, 2126, 2476, 2115, 272, 256];

beforeEach(function () {
    $this->travelTo(HabitCalendar::date('2026-10-28')->setTime(7, 0));
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

function healthLiveReading(array $data = []): array
{
    return $data + ['measured_at' => '2026-10-28T06:52:10+01:00', 'weight_kg' => 137.8, 'impedances' => HEALTH_IMPEDANCES, 'frames' => '10 14 01 02 31', 'device' => 'QN-Scale', 'firmware' => 'V48.0'];
}

function healthStoredReading(array $data = []): array
{
    return healthLiveReading($data + [
        'measured_at' => '2026-10-28T06:51:58+01:00',
        'stored' => true,
        'metrics' => ['bmi' => 45.0, 'fat_percent' => 48.2, 'muscle_percent' => 49.1, 'water_percent' => 37.4, 'visceral_or_bone' => 26, 'basal_kcal' => 1910],
        'metrics_frame' => '24 13 FF 01 C2',
    ]);
}

describe('scale sync', function () {
    it('stores a live weigh-in and merges the stored copy with its composition', function () {
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [healthLiveReading()]])
            ->assertOk()->assertJsonPath('data', ['created' => 1, 'updated' => 0]);

        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [healthStoredReading()]])
            ->assertOk()->assertJsonPath('data', ['created' => 0, 'updated' => 1]);

        $this->getJson('/api/v1/health/measurements')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.weight_kg', 137.8)
            ->assertJsonPath('data.0.source', 'scale')
            ->assertJsonPath('data.0.fat_percent', 48.2)
            ->assertJsonPath('data.0.basal_kcal', 1910)
            ->assertJsonPath('data.0.impedances', HEALTH_IMPEDANCES)
            ->assertJsonPath('data.0.firmware', 'V48.0');

        expect($this->getJson('/api/v1/health/measurements')->json('data.0.measured_at'))->toStartWith('2026-10-28T05:51:58');
    });

    it('ignores readings it already has', function () {
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [healthStoredReading()]])->assertJsonPath('data.created', 1);
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [healthStoredReading(), healthLiveReading()]])
            ->assertJsonPath('data', ['created' => 0, 'updated' => 0]);
    });

    it('keeps different weigh-ins apart', function () {
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [
            healthLiveReading(), healthLiveReading(['weight_kg' => 137.2, 'impedances' => array_map(fn ($v) => $v + 3, HEALTH_IMPEDANCES)]),
        ]])->assertJsonPath('data.created', 2);
    });

    it('validates readings', function () {
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => []])->assertJsonValidationErrors('readings');
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [healthLiveReading(['weight_kg' => 1])]])->assertJsonValidationErrors('readings.0.weight_kg');
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [healthLiveReading(['impedances' => [-1]])]])->assertJsonValidationErrors('readings.0.impedances.0');
    });
});

describe('measurements', function () {
    it('adds a manual weigh-in with the BMI from the profile', function () {
        $this->putJson('/api/v1/health/settings', ['height_cm' => 175])->assertOk();

        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 137.8])
            ->assertCreated()
            ->assertJsonPath('data.source', 'manual')
            ->assertJsonPath('data.bmi', 45.0)
            ->assertJsonPath('data.fat_percent', null);
    });

    it('filters by date and deletes', function () {
        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 139, 'measured_at' => '2026-10-01T08:00:00+02:00']);
        $id = $this->postJson('/api/v1/health/measurements', ['weight_kg' => 137.8])->json('data.id');

        $this->getJson('/api/v1/health/measurements?from=2026-10-20')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/health/measurements?to=2026-10-20')->assertJsonCount(1, 'data')->assertJsonPath('data.0.weight_kg', 139.0);
        $this->getJson("/api/v1/health/measurements/{$id}")->assertOk();
        $this->deleteJson("/api/v1/health/measurements/{$id}")->assertNoContent();
        $this->getJson('/api/v1/health/measurements')->assertJsonCount(1, 'data');
    });

    it('rejects future dates', function () {
        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 80, 'measured_at' => '2026-11-01T08:00:00+01:00'])
            ->assertJsonValidationErrors('measured_at');
    });

    it('hides other people\'s weigh-ins', function () {
        $id = $this->postJson('/api/v1/health/measurements', ['weight_kg' => 80])->json('data.id');

        $this->actingAs(User::factory()->create());
        $this->getJson("/api/v1/health/measurements/{$id}")->assertNotFound();
        $this->deleteJson("/api/v1/health/measurements/{$id}")->assertNotFound();
        $this->getJson('/api/v1/health/measurements')->assertJsonCount(0, 'data');
    });
});

describe('summary', function () {
    it('shows the latest weigh-in, its trend and the distance to the goal', function () {
        $this->putJson('/api/v1/health/settings', ['height_cm' => 175, 'birth_date' => '1990-05-01', 'sex' => 'male', 'goal_kg' => 120]);
        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 140.5, 'measured_at' => '2026-09-25T08:00:00+02:00']);
        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 139, 'measured_at' => '2026-10-20T08:00:00+02:00']);
        $this->postJson('/api/v1/health/measurements/sync', ['readings' => [healthStoredReading()]]);

        $this->getJson('/api/v1/health/summary')
            ->assertOk()
            ->assertJsonPath('data.latest.weight_kg', 137.8)
            ->assertJsonPath('data.latest_with_metrics.fat_percent', 48.2)
            ->assertJsonPath('data.change_7d', -1.2)
            ->assertJsonPath('data.change_30d', -2.7)
            ->assertJsonPath('data.goal_kg', 120.0)
            ->assertJsonPath('data.to_goal_kg', 17.8)
            ->assertJsonPath('data.weighed_today', true)
            ->assertJsonPath('data.profile_complete', true);
    });

    it('works with no weigh-ins', function () {
        $this->getJson('/api/v1/health/summary')
            ->assertOk()
            ->assertJsonPath('data.latest', null)
            ->assertJsonPath('data.change_7d', null)
            ->assertJsonPath('data.weighed_today', false)
            ->assertJsonPath('data.profile_complete', false);
    });
});

describe('settings', function () {
    it('starts with the defaults and saves the profile and reminder', function () {
        $this->getJson('/api/v1/health/settings')
            ->assertOk()
            ->assertJsonPath('data.height_cm', null)
            ->assertJsonPath('data.reminder_enabled', false)
            ->assertJsonPath('data.reminder_time', '08:00')
            ->assertJsonPath('data.reminder_days', [1, 2, 3, 4, 5, 6, 7]);

        $this->putJson('/api/v1/health/settings', [
            'height_cm' => 175, 'birth_date' => '1990-05-01', 'sex' => 'male',
            'reminder_enabled' => true, 'reminder_time' => '07:30', 'reminder_days' => [5, 1, 3, 1],
        ])->assertOk()
            ->assertJsonPath('data.age', 36)
            ->assertJsonPath('data.reminder_days', [1, 3, 5]);

        $this->putJson('/api/v1/health/settings', ['goal_kg' => 110])
            ->assertJsonPath('data.height_cm', 175)
            ->assertJsonPath('data.goal_kg', 110.0);
    });

    it('validates the settings', function () {
        $this->putJson('/api/v1/health/settings', [
            'height_cm' => 40, 'sex' => 'other', 'reminder_time' => '25:00', 'reminder_days' => [0], 'birth_date' => '2030-01-01',
        ])->assertJsonValidationErrors(['height_cm', 'sex', 'reminder_time', 'reminder_days.0', 'birth_date']);
    });
});

describe('weigh-in reminder', function () {
    beforeEach(function () {
        Notification::fake();
        $this->putJson('/api/v1/health/settings', ['reminder_enabled' => true, 'reminder_time' => '07:30', 'reminder_days' => [3]]);
    });

    it('reminds on the chosen day and time', function () {
        // 2026-10-28 is a Wednesday.
        $this->travelTo(HabitCalendar::date('2026-10-28')->setTime(7, 30));
        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 1');

        Notification::assertSentTo($this->user, WeighReminder::class);
    });

    it('stays quiet at other times, on other days or after weighing', function () {
        $this->travelTo(HabitCalendar::date('2026-10-28')->setTime(7, 31));
        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 0');

        $this->travelTo(HabitCalendar::date('2026-10-29')->setTime(7, 30));
        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 0');

        $this->travelTo(HabitCalendar::date('2026-11-04')->setTime(7, 0));
        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 137.5]);
        $this->travelTo(HabitCalendar::date('2026-11-04')->setTime(7, 30));
        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 0');

        Notification::assertNothingSent();
    });

    it('stays quiet when the reminder or the module is off', function () {
        $this->travelTo(HabitCalendar::date('2026-10-28')->setTime(7, 30));
        $this->patchJson('/api/v1/modules/health', ['enabled' => false])->assertOk();
        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 0');

        Notification::assertNothingSent();
    });

    it('opens the weigh-in screen and is pushed by default', function () {
        $payload = (new WeighReminder)->toArray($this->user);

        expect($payload['url'])->toBe('/salud/pesarse')->and($payload['module'])->toBe('health');
    });

    it('runs every minute in Madrid time', function () {
        $event = collect(app(Schedule::class)->events())
            ->first(fn ($event) => str_contains((string) $event->command, 'health:weigh-reminders'));

        expect($event?->expression)->toBe('* * * * *')
            ->and($event?->timezone)->toBe('Europe/Madrid');
    });
});

it('is blocked when the module is disabled', function () {
    $this->patchJson('/api/v1/modules/health', ['enabled' => false])->assertOk();

    $this->getJson('/api/v1/health/summary')->assertForbidden();
});
