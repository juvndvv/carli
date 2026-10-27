<?php

use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Models\Habit;

beforeEach(function () {
    $this->travelTo(HabitCalendar::date('2026-10-27')->setTime(10, 0));
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

function storeHabit(array $data = []): string
{
    return test()->postJson('/api/v1/habits', $data + ['name' => 'Meditar', 'icon' => 'leaf', 'kind' => 'check', 'period' => 'day'])
        ->assertCreated()
        ->json('data.id');
}

describe('habits', function () {
    it('creates a habit with its first goal and describes it', function () {
        $response = $this->postJson('/api/v1/habits', [
            'name' => ' Agua ', 'icon' => 'droplet', 'kind' => 'quantity', 'unit' => 'vasos', 'period' => 'day', 'target' => 8, 'preferred_time' => '08:00',
        ])->assertCreated();

        $response->assertJsonPath('data.name', 'Agua')
            ->assertJsonPath('data.kind', 'quantity')
            ->assertJsonPath('data.start_date', '2026-10-27')
            ->assertJsonPath('data.preferred_time', '08:00')
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.goal', ['period' => 'day', 'target' => 8, 'days_of_week' => null, 'valid_from' => '2026-10-27'])
            ->assertJsonPath('data.goal_text', '8 vasos al día')
            ->assertJsonPath('data.stats.streak', 0)
            ->assertJsonCount(8, 'data.weeks');
    });

    it('forces yes/no daily goals to a target of one and drops all-week day lists', function () {
        $id = storeHabit(['target' => 5, 'days_of_week' => [1, 2, 3, 4, 5, 6, 7]]);

        $this->getJson("/api/v1/habits/{$id}")->assertJsonPath('data.goal.target', 1)->assertJsonPath('data.goal.days_of_week', null);
    });

    it('validates the goal for each kind', function () {
        $this->postJson('/api/v1/habits', ['name' => 'Agua', 'icon' => 'droplet', 'kind' => 'quantity', 'period' => 'day'])->assertJsonValidationErrors('target');
        $this->postJson('/api/v1/habits', ['name' => 'Correr', 'icon' => 'running', 'kind' => 'check', 'period' => 'week', 'target' => 9])->assertJsonValidationErrors('target');
        $this->postJson('/api/v1/habits', ['name' => 'Correr', 'icon' => 'running', 'kind' => 'check', 'period' => 'week'])->assertJsonValidationErrors('target');
        $this->postJson('/api/v1/habits', ['name' => 'X', 'icon' => 'rocket', 'kind' => 'check', 'period' => 'day'])->assertJsonValidationErrors('icon');
        $this->postJson('/api/v1/habits', ['name' => 'X', 'icon' => 'check', 'kind' => 'check', 'period' => 'day', 'days_of_week' => [0, 8]])->assertJsonValidationErrors(['days_of_week.0', 'days_of_week.1']);
    });

    it('creates an avoid habit with a maximum of zero by default', function () {
        $this->postJson('/api/v1/habits', ['name' => 'Tabaco', 'icon' => 'cigarette', 'kind' => 'avoid', 'period' => 'day'])
            ->assertCreated()
            ->assertJsonPath('data.goal.target', 0)
            ->assertJsonPath('data.goal_text', 'Nada');
    });

    it('does not let the kind change', function () {
        $id = storeHabit();

        $this->patchJson("/api/v1/habits/{$id}", ['kind' => 'avoid'])->assertJsonValidationErrors('kind');
    });

    it('applies a goal change from today and keeps the past with its old goal', function () {
        $id = storeHabit(['name' => 'Agua', 'icon' => 'droplet', 'kind' => 'quantity', 'unit' => 'vasos', 'target' => 8, 'start_date' => '2026-10-20']);
        foreach (['2026-10-25', '2026-10-26', '2026-10-27'] as $date) {
            $this->putJson("/api/v1/habits/{$id}/entries/{$date}", ['value' => 6])->assertOk();
        }

        $response = $this->patchJson("/api/v1/habits/{$id}", ['target' => 5])->assertOk();

        expect($response->json('data.goals'))->toBe([
            ['valid_from' => '2026-10-20', 'period' => 'day', 'target' => 8, 'days_of_week' => null],
            ['valid_from' => '2026-10-27', 'period' => 'day', 'target' => 5, 'days_of_week' => null],
        ])->and($response->json('data.today.met'))->toBeTrue()
            ->and($response->json('data.stats.streak'))->toBe(1);

        $this->patchJson("/api/v1/habits/{$id}", ['target' => 4])->assertOk()->assertJsonCount(2, 'data.goals')->assertJsonPath('data.goals.1.target', 4);
        $this->patchJson("/api/v1/habits/{$id}", ['name' => 'Agua (vasos)'])->assertOk()->assertJsonCount(2, 'data.goals');
    });

    it('updates the first goal in place on the start day', function () {
        $id = storeHabit(['kind' => 'check', 'period' => 'week', 'target' => 3]);

        $this->patchJson("/api/v1/habits/{$id}", ['target' => 2])->assertOk()->assertJsonCount(1, 'data.goals')->assertJsonPath('data.goal_text', '2 veces por semana');
    });

    it('lists habits with consistency and the current week in seven cells', function () {
        $id = storeHabit(['start_date' => '2026-10-19']);
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-26", ['value' => 1]);
        $paused = storeHabit(['name' => 'Inglés']);
        $this->postJson("/api/v1/habits/{$paused}/pause")->assertOk()->assertJsonPath('data.status', 'paused');

        $response = $this->getJson('/api/v1/habits')->assertOk();

        expect($response->json('data.*.name'))->toBe(['Meditar', 'Inglés'])
            ->and($response->json('data.0.week.*.state'))->toBe(['done', 'today', 'future', 'future', 'future', 'future', 'future'])
            ->and($response->json('data.0.consistency'))->toBe(13)
            ->and($response->json('data.1.status'))->toBe('paused');
    });

    it('reorders habits', function () {
        $first = storeHabit(['name' => 'Uno']);
        $second = storeHabit(['name' => 'Dos']);

        $this->putJson('/api/v1/habits/order', ['ids' => [$second, $first]])->assertNoContent();

        expect($this->getJson('/api/v1/habits')->json('data.*.name'))->toBe(['Dos', 'Uno']);
    });

    it('deletes a habit with its history', function () {
        $id = storeHabit();
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", ['value' => 1]);

        $this->deleteJson("/api/v1/habits/{$id}")->assertNoContent();

        expect(Habit::query()->count())->toBe(0)
            ->and(DB::table('habits.habit_entries')->count())->toBe(0);
    });

    it('keeps other users out', function () {
        $id = storeHabit();
        $this->actingAs(User::factory()->create());

        $this->getJson("/api/v1/habits/{$id}")->assertNotFound();
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", ['value' => 1])->assertNotFound();
        expect($this->getJson('/api/v1/habits')->json('data'))->toBe([]);
    });

    it('is closed when the module is disabled', function () {
        $this->patchJson('/api/v1/modules/habits', ['enabled' => false])->assertOk();

        $this->getJson('/api/v1/habits/today')->assertForbidden();
    });

    it('finds habits in the global search', function () {
        storeHabit(['name' => 'Leer 20 páginas', 'icon' => 'book-open']);

        $results = $this->getJson('/api/v1/search?q=leer')->assertOk()->json('data');

        expect(collect($results)->firstWhere('type', 'habit'))->toMatchArray(['title' => 'Leer 20 páginas', 'subtitle' => 'Cada día', 'url' => collect($results)->firstWhere('type', 'habit')['url']]);
    });
});

describe('entries', function () {
    it('logs today and returns the updated today card', function () {
        $id = storeHabit(['name' => 'Agua', 'icon' => 'droplet', 'kind' => 'quantity', 'unit' => 'vasos', 'target' => 8]);

        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", ['value' => 3, 'note' => 'mañana'])
            ->assertOk()
            ->assertJsonPath('data.entry', ['date' => '2026-10-27', 'value' => 3, 'note' => 'mañana', 'source' => 'manual'])
            ->assertJsonPath('data.today.value', 3)
            ->assertJsonPath('data.today.today_note', 'mañana')
            ->assertJsonPath('data.today.progress', 0.375)
            ->assertJsonPath('data.today.status', 'current');

        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", ['value' => 8])->assertJsonPath('data.today.met', true);
    });

    it('removes the entry when the value goes back to zero', function () {
        $id = storeHabit();
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", ['value' => 1])->assertJsonPath('data.today.met', true);

        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", ['value' => 0])->assertOk()->assertJsonPath('data.entry', null)->assertJsonPath('data.today.met', false);

        expect(DB::table('habits.habit_entries')->count())->toBe(0);
    });

    it('logs and corrects past days', function () {
        $id = storeHabit(['start_date' => '2026-10-20']);

        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-21", ['value' => 1])->assertOk();
        $this->deleteJson("/api/v1/habits/{$id}/entries/2026-10-21")->assertOk()->assertJsonPath('data.entry', null);
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-22", ['value' => 1])->assertOk();

        $days = collect($this->getJson("/api/v1/habits/{$id}/calendar?month=2026-10")->assertOk()->json('data.days'))->keyBy('date');

        expect($days['2026-10-19']['state'])->toBe('none')
            ->and($days['2026-10-21']['state'])->toBe('miss')
            ->and($days['2026-10-22']['state'])->toBe('done')
            ->and($days['2026-10-27']['state'])->toBe('today')
            ->and($days['2026-10-28']['state'])->toBe('future');
    });

    it('rejects future days, days before the start and odd yes/no values', function () {
        $id = storeHabit(['start_date' => '2026-10-20']);

        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-28", ['value' => 1])->assertJsonValidationErrors('date');
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-19", ['value' => 1])->assertJsonValidationErrors('date');
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", ['value' => 2])->assertJsonValidationErrors('value');
        $this->putJson("/api/v1/habits/{$id}/entries/2026-10-27", [])->assertJsonValidationErrors('value');
    });
});

describe('today', function () {
    it('lists what is due today with the day progress, without avoid habits in the count', function () {
        $meditate = storeHabit(['start_date' => '2026-10-20']);
        $water = storeHabit(['name' => 'Agua', 'icon' => 'droplet', 'kind' => 'quantity', 'unit' => 'vasos', 'target' => 8]);
        $run = storeHabit(['name' => 'Correr', 'icon' => 'running', 'kind' => 'check', 'period' => 'week', 'target' => 1, 'start_date' => '2026-10-26']);
        storeHabit(['name' => 'Gimnasio', 'icon' => 'dumbbell', 'days_of_week' => [1, 3, 5]]);
        $coffee = storeHabit(['name' => 'Café', 'icon' => 'coffee', 'kind' => 'avoid', 'unit' => 'cafés', 'target' => 2]);
        foreach (['2026-10-24', '2026-10-25', '2026-10-26', '2026-10-27'] as $date) {
            $this->putJson("/api/v1/habits/{$meditate}/entries/{$date}", ['value' => 1]);
        }
        $this->putJson("/api/v1/habits/{$run}/entries/2026-10-26", ['value' => 1]);
        $this->putJson("/api/v1/habits/{$coffee}/entries/2026-10-27", ['value' => 3]);

        $response = $this->getJson('/api/v1/habits/today')->assertOk();
        $items = collect($response->json('data.habits'))->keyBy('name');

        expect($response->json('data.summary'))->toBe(['done' => 2, 'total' => 3, 'consistency' => 50])
            ->and($items->keys()->all())->toBe(['Meditar', 'Agua', 'Correr', 'Café'])
            ->and($items['Meditar'])->toMatchArray(['met' => true, 'streak' => 4, 'streak_unit' => 'day'])
            ->and($items['Agua'])->toMatchArray(['met' => false, 'status' => 'current', 'target' => 8, 'value' => 0])
            ->and($items['Correr'])->toMatchArray(['met' => true, 'period' => 'week', 'period_end' => '2026-11-01', 'days_left' => 6])
            ->and($items['Café'])->toMatchArray(['over' => true, 'met' => false, 'status' => 'missed', 'value' => 3]);
    });

    it('hides paused, archived and not yet started habits', function () {
        $paused = storeHabit(['name' => 'Pausado']);
        $archived = storeHabit(['name' => 'Archivado']);
        storeHabit(['name' => 'Futuro', 'start_date' => '2026-11-02']);
        $this->postJson("/api/v1/habits/{$paused}/pause");
        $this->postJson("/api/v1/habits/{$archived}/archive")->assertJsonPath('data.status', 'archived');

        expect($this->getJson('/api/v1/habits/today')->json('data.habits'))->toBe([]);
    });

    it('never puts habits in the shared pending inbox', function () {
        $id = storeHabit(['start_date' => '2026-10-01']);

        $this->getJson('/api/v1/pending/summary')->assertOk()->assertJsonPath('data.total', 0);
        expect($this->getJson('/api/v1/pending')->json('data'))->toBe([]);
    });
});

describe('breaks', function () {
    it('takes every habit off today during a global break', function () {
        storeHabit(['start_date' => '2026-10-20']);

        $break = $this->postJson('/api/v1/habits/breaks', ['from_date' => '2026-10-25', 'to_date' => '2026-11-03'])
            ->assertCreated()
            ->assertJsonPath('data.active', true)
            ->json('data.id');

        $this->getJson('/api/v1/habits/today')->assertJsonPath('data.on_break', true)->assertJsonPath('data.habits', []);

        $this->postJson("/api/v1/habits/breaks/{$break}/end")->assertOk()->assertJsonPath('data.to_date', '2026-10-26');
        $this->getJson('/api/v1/habits/today')->assertJsonPath('data.on_break', false)->assertJsonCount(1, 'data.habits');
    });

    it('puts a single habit on break and shows it grey in the calendar', function () {
        $id = storeHabit(['start_date' => '2026-10-20']);
        $other = storeHabit(['name' => 'Leer', 'icon' => 'book-open', 'start_date' => '2026-10-20']);

        $this->postJson('/api/v1/habits/breaks', ['habit_id' => $id, 'from_date' => '2026-10-21', 'to_date' => '2026-10-27'])->assertCreated();

        $days = collect($this->getJson("/api/v1/habits/{$id}/calendar?month=2026-10")->json('data.days'))->keyBy('date');
        expect($days['2026-10-20']['state'])->toBe('miss')
            ->and($days['2026-10-23']['state'])->toBe('rest')
            ->and(collect($this->getJson('/api/v1/habits/today')->json('data.habits'))->pluck('id')->all())->toBe([$other]);
    });

    it('validates breaks', function () {
        $this->postJson('/api/v1/habits/breaks', ['from_date' => '2026-10-25', 'to_date' => '2026-10-20'])->assertJsonValidationErrors('to_date');
        $this->postJson('/api/v1/habits/breaks', ['habit_id' => fake()->uuid(), 'from_date' => '2026-10-25', 'to_date' => '2026-10-26'])->assertJsonValidationErrors('habit_id');
    });

    it('deletes an upcoming break when it is ended before it starts', function () {
        $break = $this->postJson('/api/v1/habits/breaks', ['from_date' => '2026-11-10', 'to_date' => '2026-11-12'])->assertJsonPath('data.upcoming', true)->json('data.id');

        $this->postJson("/api/v1/habits/breaks/{$break}/end")->assertOk()->assertJsonPath('data', null);

        expect($this->getJson('/api/v1/habits/breaks')->json('data'))->toBe([]);
    });

    it('excuses the paused days once the habit is resumed', function () {
        $id = storeHabit(['start_date' => '2026-10-20']);
        $this->travelTo(HabitCalendar::date('2026-10-22')->setTime(9, 0));
        $this->postJson("/api/v1/habits/{$id}/pause")->assertOk();
        $this->travelTo(HabitCalendar::date('2026-10-27')->setTime(9, 0));

        $this->postJson("/api/v1/habits/{$id}/resume")->assertOk()->assertJsonPath('data.status', 'active');

        $days = collect($this->getJson("/api/v1/habits/{$id}/calendar")->json('data.days'))->keyBy('date');
        expect($days['2026-10-21']['state'])->toBe('miss')
            ->and($days['2026-10-22']['state'])->toBe('rest')
            ->and($days['2026-10-26']['state'])->toBe('rest')
            ->and($days['2026-10-27']['state'])->toBe('today')
            ->and($this->getJson('/api/v1/habits/breaks')->json('data.0'))->toMatchArray(['habit_id' => $id, 'from_date' => '2026-10-22', 'to_date' => '2026-10-26']);
    });
});

describe('detail and progress', function () {
    it('shows constancy, streaks and weekly bars', function () {
        $id = storeHabit(['start_date' => '2026-10-12']);
        foreach (['2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15', '2026-10-20', '2026-10-21', '2026-10-26', '2026-10-27'] as $date) {
            $this->putJson("/api/v1/habits/{$id}/entries/{$date}", ['value' => 1]);
        }

        $response = $this->getJson("/api/v1/habits/{$id}")->assertOk();

        expect($response->json('data.stats'))->toBe([
            'consistency' => 50,
            'consistency_all' => 50,
            'streak' => 2,
            'best_streak' => 4,
            'best_streak_end' => '2026-10-15',
            'streak_unit' => 'day',
        ])->and(array_slice($response->json('data.weeks'), -3))->toBe([
            ['start' => '2026-10-12', 'value' => 4, 'target' => 7],
            ['start' => '2026-10-19', 'value' => 2, 'target' => 7],
            ['start' => '2026-10-26', 'value' => 2, 'target' => 2],
        ]);
    });

    it('summarises a week, a month and a year with the trend against the previous one', function () {
        $daily = storeHabit(['start_date' => '2026-10-19']);
        $weekly = storeHabit(['name' => 'Correr', 'icon' => 'running', 'period' => 'week', 'target' => 2, 'start_date' => '2026-10-19']);
        foreach (['2026-10-19', '2026-10-20', '2026-10-26', '2026-10-27'] as $date) {
            $this->putJson("/api/v1/habits/{$daily}/entries/{$date}", ['value' => 1]);
        }
        $this->putJson("/api/v1/habits/{$weekly}/entries/2026-10-21", ['value' => 1]);
        $this->putJson("/api/v1/habits/{$weekly}/entries/2026-10-23", ['value' => 1]);

        $week = $this->getJson('/api/v1/habits/progress?range=week')->assertOk();

        expect($week->json('data'))->toMatchArray(['from' => '2026-10-26', 'to' => '2026-11-01', 'consistency' => 100, 'met' => 2, 'total' => 2, 'previous_consistency' => 38, 'trend' => 62])
            ->and($week->json('data.columns'))->toHaveCount(7)
            ->and($week->json('data.habits.0.cells.*.state'))->toBe(['done', 'done', 'future', 'future', 'future', 'future', 'future'])
            ->and($week->json('data.habits.1.cells.*.state'))->toBe(['off', 'today', 'future', 'future', 'future', 'future', 'future']);

        $month = $this->getJson('/api/v1/habits/progress?range=month')->assertOk();
        expect($month->json('data'))->toMatchArray(['from' => '2026-10-01', 'to' => '2026-10-31', 'met' => 5, 'total' => 10, 'previous_consistency' => null, 'trend' => null])
            ->and($month->json('data.columns'))->toHaveCount(31);

        $year = $this->getJson('/api/v1/habits/progress?range=year')->assertOk();
        expect($year->json('data.columns'))->toHaveCount(12)
            ->and($year->json('data.habits.0.cells.9'))->toBe(['month' => '2026-10', 'consistency' => 44]);
    });
});
