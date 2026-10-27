<?php

use App\Core\Notifications\NotificationPreferenceService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Notifications\PayrollOverdue;
use App\Modules\Finance\Notifications\UpcomingCharge;
use App\Modules\Finance\Notifications\WeeklySummary;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Notification;

beforeEach(function () {
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-09-28')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user);
    F::income($this->user, $this->account, 200000, '2026-09-28');
});

it('warns once when the expected payroll has not been registered', function () {
    $this->artisan('finance:payroll-overdue', ['--date' => '2026-10-28'])->assertSuccessful();
    Notification::assertNothingSent();

    $this->artisan('finance:payroll-overdue', ['--date' => '2026-10-29'])->assertSuccessful();
    Notification::assertSentToTimes($this->user, PayrollOverdue::class, 1);

    $this->artisan('finance:payroll-overdue', ['--date' => '2026-10-30'])->assertSuccessful();
    Notification::assertSentToTimes($this->user, PayrollOverdue::class, 1);
});

it('sends the weekly summary when enabled', function () {
    app(NotificationPreferenceService::class)->update($this->user, [
        ['module' => 'finance', 'type' => 'weekly_summary', 'push' => true, 'in_app' => true],
    ]);
    F::expense($this->user, $this->account, 3120, '2026-10-21');
    $this->travelTo(SpanishCalendar::date('2026-10-26')->setTime(9, 0));

    $this->artisan('finance:weekly-summary')->assertSuccessful();

    Notification::assertSentTo($this->user, WeeklySummary::class, fn (WeeklySummary $notification) => $notification->spentCents === 3120
        && str_contains($notification->body(), '31,20 €')
        && $notification->toArray($this->user)['url'] === '/finanzas');
});

it('registers the scheduled tasks in Madrid time', function () {
    $events = collect(app(Schedule::class)->events())->mapWithKeys(fn ($event) => [trim(str($event->command)->after('artisan')->replace("'", '')->toString()) => $event]);

    expect($events->keys()->all())->toContain('finance:materialize-recurring', 'finance:upcoming-charges', 'finance:payroll-overdue', 'finance:weekly-summary')
        ->and($events['finance:materialize-recurring']->expression)->toBe('0 6 * * *')
        ->and($events['finance:weekly-summary']->expression)->toBe('0 9 * * 1')
        ->and($events['finance:upcoming-charges']->timezone)->toBe('Europe/Madrid');
});

it('builds apns payloads that open the recurring charges screen on tap', function () {
    $notification = new UpcomingCharge('rule', 'Netflix', -1399, 2, '2026-10-30');

    expect($notification->toApns($this->user)->payload())->toBe([
        'aps' => [
            'alert' => ['title' => 'Netflix 13,99 € pasado mañana', 'body' => $notification->body()],
            'sound' => 'default',
            'thread-id' => 'finance.'.$notification->type()->value,
        ],
        'url' => '/finanzas/recurrentes',
    ]);
});
