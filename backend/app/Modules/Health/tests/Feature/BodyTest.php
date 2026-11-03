<?php

use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Notifications\WeighReminder;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    $this->travelTo(HabitCalendar::date('2026-11-03')->setTime(9, 0));
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

function bodySiteId(string $name): string
{
    return collect(test()->getJson('/api/v1/health/body/sites')->json('data'))->firstWhere('name', $name)['id'];
}

describe('body sites', function () {
    it('starts with the default sites, once', function () {
        $this->getJson('/api/v1/health/body/sites')
            ->assertOk()
            ->assertJsonCount(11, 'data')
            ->assertJsonPath('data.0.name', 'Cuello')
            ->assertJsonPath('data.2.zone', 'arm')
            ->assertJsonPath('data.2.side', 'left');

        foreach ($this->getJson('/api/v1/health/body/sites')->json('data') as $site) {
            $this->deleteJson("/api/v1/health/body/sites/{$site['id']}")->assertNoContent();
        }

        $this->getJson('/api/v1/health/body/sites')->assertJsonCount(0, 'data');
    });

    it('creates, edits, archives and reorders custom sites', function () {
        $id = $this->postJson('/api/v1/health/body/sites', ['name' => 'Antebrazo derecho', 'zone' => 'forearm', 'side' => 'right'])
            ->assertCreated()
            ->assertJsonPath('data.position', 11)
            ->json('data.id');

        // A zone that isn't paired drops the side.
        $this->patchJson("/api/v1/health/body/sites/{$id}", ['zone' => 'waist', 'name' => 'Cintura baja'])
            ->assertOk()
            ->assertJsonPath('data.side', null)
            ->assertJsonPath('data.name', 'Cintura baja');

        $this->patchJson("/api/v1/health/body/sites/{$id}", ['archived' => true])->assertJsonPath('data.archived', true);
        $this->getJson('/api/v1/health/body/sites')->assertJsonCount(11, 'data');
        $this->getJson('/api/v1/health/body/sites?archived=1')->assertJsonCount(12, 'data');

        $neck = bodySiteId('Cuello');
        $this->putJson('/api/v1/health/body/sites/order', ['ids' => [$id, $neck]])->assertNoContent();
        $this->getJson('/api/v1/health/body/sites?archived=1')->assertJsonPath('data.0.id', $id)->assertJsonPath('data.1.id', $neck);
    });

    it('validates sites', function () {
        $this->postJson('/api/v1/health/body/sites', ['name' => '', 'zone' => 'tail', 'side' => 'middle'])
            ->assertJsonValidationErrors(['name', 'zone', 'side']);
    });

    it('keeps other users out', function () {
        $neck = bodySiteId('Cuello');
        $this->actingAs(User::factory()->create());

        $this->patchJson("/api/v1/health/body/sites/{$neck}", ['name' => 'x'])->assertNotFound();
        $this->getJson("/api/v1/health/body/sites/{$neck}/measurements")->assertNotFound();
        $this->postJson('/api/v1/health/body/measurements', ['values' => [['site_id' => $neck, 'value_cm' => 40]]])
            ->assertJsonValidationErrors(['values.0.site_id']);
    });
});

describe('body measurements', function () {
    it('records a session and shows the change on the viewer', function () {
        $waist = bodySiteId('Cintura');
        $arm = bodySiteId('Brazo izquierdo');

        $this->travelTo(HabitCalendar::date('2026-09-01')->setTime(9, 0));
        $this->postJson('/api/v1/health/body/measurements', ['values' => [
            ['site_id' => $waist, 'value_cm' => 120.4], ['site_id' => $arm, 'value_cm' => 38],
        ]])->assertCreated()->assertJsonCount(2, 'data');

        $this->travelTo(HabitCalendar::date('2026-10-01')->setTime(9, 0));
        $this->postJson('/api/v1/health/body/measurements', ['values' => [['site_id' => $waist, 'value_cm' => 117]]])->assertCreated();

        $this->travelTo(HabitCalendar::date('2026-11-03')->setTime(9, 0));
        $this->postJson('/api/v1/health/body/measurements', ['values' => [['site_id' => $waist, 'value_cm' => 114.5]]])->assertCreated();

        $sites = collect($this->getJson('/api/v1/health/body')->assertOk()->assertJsonPath('data.measured_today', true)->json('data.sites'));
        $row = $sites->firstWhere('id', $waist);
        expect($row['latest']['value_cm'])->toEqual(114.5)
            ->and($row['baseline']['value_cm'])->toEqual(120.4)
            ->and($row['change_cm'])->toEqual(-5.9)
            ->and($row['count'])->toBe(3);
        // A single measurement has nothing to compare with.
        $arm = $sites->firstWhere('id', $arm);
        expect($arm['baseline'])->toBeNull()->and($arm['change_cm'])->toBeNull();
        expect($sites->firstWhere('name', 'Cuello')['latest'])->toBeNull();

        $byDay = collect($this->getJson('/api/v1/health/body?compare=2026-10-15')->json('data.sites'))->firstWhere('id', $waist);
        expect($byDay['baseline']['value_cm'])->toEqual(117)->and($byDay['change_cm'])->toEqual(-2.5);

        $this->getJson("/api/v1/health/body/sites/{$waist}/measurements")
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.value_cm', 120.4);
        $this->assertSame('2026-11-03', substr((string) $this->getJson('/api/v1/health/body')->json('data.last_measured_at'), 0, 10));
        $this->getJson("/api/v1/health/body/sites/{$waist}/measurements?from=2026-10-01")->assertJsonCount(2, 'data');
    });

    it('deletes a measurement', function () {
        $waist = bodySiteId('Cintura');
        $id = $this->postJson('/api/v1/health/body/measurements', ['values' => [['site_id' => $waist, 'value_cm' => 110]]])->json('data.0.id');

        $this->deleteJson("/api/v1/health/body/measurements/{$id}")->assertNoContent();
        $this->getJson("/api/v1/health/body/sites/{$waist}/measurements")->assertJsonCount(0, 'data');
    });

    it('validates a session', function () {
        $waist = bodySiteId('Cintura');

        $this->postJson('/api/v1/health/body/measurements', ['values' => [['site_id' => $waist, 'value_cm' => 0]], 'measured_at' => '2030-01-01'])
            ->assertJsonValidationErrors(['values.0.value_cm', 'measured_at']);
        $this->postJson('/api/v1/health/body/measurements', ['values' => []])->assertJsonValidationErrors(['values']);
        $this->getJson('/api/v1/health/body?compare=ayer')->assertJsonValidationErrors(['compare']);
    });
});

describe('measurement reminder', function () {
    beforeEach(function () {
        Notification::fake();
        // 2026-11-03 is a Tuesday.
        $this->putJson('/api/v1/health/settings', ['reminder_enabled' => true, 'reminder_time' => '09:30', 'reminder_days' => [2]]);
    });

    it('covers only the weight by default', function () {
        $this->getJson('/api/v1/health/settings')
            ->assertJsonPath('data.reminder_weight', true)
            ->assertJsonPath('data.reminder_body', false);
    });

    it('says what is missing today', function () {
        $this->putJson('/api/v1/health/settings', ['reminder_body' => true])->assertJsonPath('data.reminder_body', true);
        $this->travelTo(HabitCalendar::date('2026-11-03')->setTime(9, 30));

        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 1');
        Notification::assertSentTo($this->user, WeighReminder::class, fn (WeighReminder $n) => $n->missing === ['weight', 'body']
            && $n->toArray($this->user)['title'] === 'Hora de pesarse y medirse'
            && $n->toArray($this->user)['url'] === '/salud/pesarse');
    });

    it('asks only for the measurements once weighed', function () {
        $this->putJson('/api/v1/health/settings', ['reminder_body' => true]);
        $this->postJson('/api/v1/health/measurements', ['weight_kg' => 120]);
        $this->travelTo(HabitCalendar::date('2026-11-03')->setTime(9, 30));

        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 1');
        Notification::assertSentTo($this->user, WeighReminder::class, fn (WeighReminder $n) => $n->missing === ['body']
            && $n->toArray($this->user)['url'] === '/salud/medirse');
    });

    it('stays quiet when everything included is done', function () {
        $this->putJson('/api/v1/health/settings', ['reminder_weight' => false, 'reminder_body' => true]);
        $this->postJson('/api/v1/health/body/measurements', ['values' => [['site_id' => bodySiteId('Cintura'), 'value_cm' => 110]]]);
        $this->travelTo(HabitCalendar::date('2026-11-03')->setTime(9, 30));

        $this->artisan('health:weigh-reminders')->expectsOutputToContain('Recordatorios enviados: 0');
        Notification::assertNothingSent();
    });
});
