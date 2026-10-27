<?php

namespace App\Modules\Habits\Domain\Services;

use App\Models\User;
use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Enums\PeriodStatus;
use App\Modules\Habits\Domain\Evaluation\HabitEvaluator;
use App\Modules\Habits\Domain\Evaluation\HabitStats;
use App\Modules\Habits\Domain\Evaluation\Period;
use App\Modules\Habits\Domain\Evaluation\Timeline;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Http\Resources\HabitResource;
use App\Modules\Habits\Models\Habit;
use App\Modules\Habits\Models\HabitBreak;
use App\Modules\Habits\Models\HabitEntry;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;

final class HabitReport
{
    public const int DETAIL_WEEKS = 8;

    public function __construct(private readonly HabitEvaluator $evaluator) {}

    /**
     * @param  Collection<int, HabitBreak>|null  $globalBreaks
     */
    public function timeline(Habit $habit, ?Collection $globalBreaks = null): Timeline
    {
        $habit->loadMissing(['goals', 'entries', 'breaks']);

        return Timeline::fromHabit($habit, $globalBreaks ?? $this->globalBreaks($habit->user_id));
    }

    /**
     * @param  Collection<int, HabitBreak>|null  $globalBreaks
     * @return list<Period>
     */
    public function periods(Habit $habit, ?CarbonImmutable $today = null, ?Collection $globalBreaks = null): array
    {
        return $this->evaluator->periods($this->timeline($habit, $globalBreaks), $today ?? HabitCalendar::today());
    }

    /**
     * @return array<string, mixed>
     */
    public function today(User $user): array
    {
        $today = HabitCalendar::today();
        $breaks = $this->globalBreaks($user->id);
        $items = [];
        $tally = ['met' => 0, 'total' => 0];

        foreach ($this->habits($user) as $habit) {
            if ($habit->start_date->gt($today)) {
                continue;
            }

            $periods = $this->periods($habit, $today, $breaks);
            $window = HabitStats::tally($periods, HabitStats::windowStart($today));
            $tally = ['met' => $tally['met'] + $window['met'], 'total' => $tally['total'] + $window['total']];
            $item = $this->todayItem($habit, $periods, $today);

            if ($item !== null) {
                $items[] = $item;
            }
        }

        $countable = array_filter($items, fn (array $item) => $item['kind'] !== HabitKind::Avoid->value);

        return [
            'date' => $today->toDateString(),
            'on_break' => $breaks->contains(fn (HabitBreak $break) => $break->covers($today)),
            'summary' => [
                'done' => count(array_filter($countable, fn (array $item) => $item['met'])),
                'total' => count($countable),
                'consistency' => HabitStats::percent($tally),
            ],
            'habits' => $items,
        ];
    }

    /**
     * @param  list<Period>|null  $periods
     * @return array<string, mixed>|null
     */
    public function todayItem(Habit $habit, ?array $periods = null, ?CarbonImmutable $today = null): ?array
    {
        $today ??= HabitCalendar::today();

        if (! $habit->isActive() || $habit->start_date->gt($today)) {
            return null;
        }

        $periods ??= $this->periods($habit, $today);
        $current = $periods === [] ? null : $periods[array_key_last($periods)];

        if ($current === null || ! $current->contains($today) || in_array($current->status, [PeriodStatus::Off, PeriodStatus::Excused], true)) {
            return null;
        }

        /** @var HabitEntry|null $entry */
        $entry = $habit->entries->first(fn (HabitEntry $entry) => $entry->date->isSameDay($today));

        return [
            ...HabitResource::make($habit)->resolve(),
            'period' => $current->period->value,
            'period_start' => $current->start->toDateString(),
            'period_end' => $current->end->toDateString(),
            'target' => $current->target,
            'value' => $current->value,
            'today_value' => $entry === null ? 0.0 : $entry->value,
            'today_note' => $entry?->note,
            'status' => $current->status->value,
            'met' => $current->isMet(),
            'over' => $habit->kind === HabitKind::Avoid && $current->status === PeriodStatus::Missed,
            'progress' => $this->ratio($habit->kind, $current),
            'days_left' => (int) $today->diffInDays($current->end) + 1,
            'streak' => HabitStats::streak($periods),
            'streak_unit' => $current->period->value,
            'consistency' => HabitStats::consistency($periods, $today),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function list(User $user): array
    {
        $today = HabitCalendar::today();
        $week = $this->days(HabitCalendar::weekStart($today), HabitCalendar::weekEnd($today));
        $breaks = $this->globalBreaks($user->id);
        $items = [];

        foreach ($this->habits($user, includeInactive: true) as $habit) {
            $timeline = $this->timeline($habit, $breaks);
            $periods = $this->evaluator->periods($timeline, $today);
            $index = $this->index($periods);

            $items[] = [
                ...HabitResource::make($habit)->resolve(),
                'consistency' => HabitStats::consistency($periods, $today),
                'streak' => HabitStats::streak($periods),
                'streak_unit' => $timeline->currentGoal()->period->value,
                'week' => array_map(fn (CarbonImmutable $day) => ['date' => $day->toDateString(), 'state' => $this->dayState($timeline, $index, $day, $today)], $week),
            ];
        }

        return $items;
    }

    /**
     * @return array<string, mixed>
     */
    public function detail(Habit $habit): array
    {
        $today = HabitCalendar::today();
        $timeline = $this->timeline($habit);
        $periods = $this->evaluator->periods($timeline, $today);
        $best = HabitStats::bestStreak($periods);
        $first = HabitCalendar::weekStart($today)->subWeeks(self::DETAIL_WEEKS - 1);

        return [
            ...HabitResource::make($habit)->resolve(),
            'stats' => [
                'consistency' => HabitStats::consistency($periods, $today),
                'consistency_all' => HabitStats::percent(HabitStats::tally($periods)),
                'streak' => HabitStats::streak($periods),
                'best_streak' => $best['length'],
                'best_streak_end' => $best['end']?->toDateString(),
                'streak_unit' => $timeline->currentGoal()->period->value,
            ],
            'goals' => $habit->goals->map(fn ($goal) => [
                'valid_from' => $goal->valid_from->toDateString(),
                'period' => $goal->period->value,
                'target' => $goal->target,
                'days_of_week' => $goal->days_of_week,
            ])->values()->all(),
            'weeks' => array_map(fn (int $offset) => $this->weekBar($timeline, $periods, $first->addWeeks($offset), $today), range(0, self::DETAIL_WEEKS - 1)),
            'today' => $this->todayItem($habit, $periods, $today),
        ];
    }

    /**
     * @return array{month: string, days: list<array{date: string, state: string, value: float, note: string|null}>}
     */
    public function calendar(Habit $habit, CarbonImmutable $month): array
    {
        $today = HabitCalendar::today();
        $timeline = $this->timeline($habit);
        $index = $this->index($this->evaluator->periods($timeline, $today));
        $notes = $habit->entries->mapWithKeys(fn (HabitEntry $entry) => [$entry->date->toDateString() => $entry->note])->all();

        return [
            'month' => $month->format('Y-m'),
            'days' => array_map(fn (CarbonImmutable $day) => [
                'date' => $day->toDateString(),
                'state' => $this->dayState($timeline, $index, $day, $today),
                'value' => $timeline->valueOn($day),
                'note' => $notes[$day->toDateString()] ?? null,
            ], $this->days($month->startOfMonth(), $month->endOfMonth()->startOfDay())),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function progress(User $user, string $range, CarbonImmutable $date): array
    {
        $today = HabitCalendar::today();
        [$from, $to] = $this->bounds($range, $date);
        [$previousFrom, $previousTo] = $this->bounds($range, $this->previous($range, $from));
        $current = ['met' => 0, 'total' => 0];
        $previous = ['met' => 0, 'total' => 0];
        $breaks = $this->globalBreaks($user->id);
        $rows = [];

        foreach ($this->habits($user, includeInactive: true) as $habit) {
            if ($habit->archived_at !== null || $habit->start_date->gt($to)) {
                continue;
            }

            $timeline = $this->timeline($habit, $breaks);
            $periods = $this->evaluator->periods($timeline, $today);
            $index = $this->index($periods);
            $own = HabitStats::tally($periods, $from, $to);
            $before = HabitStats::tally($periods, $previousFrom, $previousTo);
            $current = ['met' => $current['met'] + $own['met'], 'total' => $current['total'] + $own['total']];
            $previous = ['met' => $previous['met'] + $before['met'], 'total' => $previous['total'] + $before['total']];
            $percent = HabitStats::percent($own);
            $before = HabitStats::percent($before);

            $rows[] = [
                'id' => $habit->id,
                'name' => $habit->name,
                'icon' => $habit->icon,
                'kind' => $habit->kind->value,
                'paused' => $habit->paused_at !== null,
                'consistency' => $percent,
                'met' => $own['met'],
                'total' => $own['total'],
                'trend' => $percent === null || $before === null ? null : $percent - $before,
                'cells' => $range === 'year'
                    ? $this->monthCells($periods, $from)
                    : array_map(fn (CarbonImmutable $day) => ['date' => $day->toDateString(), 'state' => $this->dayState($timeline, $index, $day, $today)], $this->days($from, $to)),
            ];
        }

        $percent = HabitStats::percent($current);
        $before = HabitStats::percent($previous);

        return [
            'range' => $range,
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'previous_from' => $previousFrom->toDateString(),
            'previous_to' => $previousTo->toDateString(),
            'consistency' => $percent,
            'met' => $current['met'],
            'total' => $current['total'],
            'previous_consistency' => $before,
            'trend' => $percent === null || $before === null ? null : $percent - $before,
            'columns' => $range === 'year'
                ? array_map(fn (int $month) => $from->addMonths($month)->format('Y-m'), range(0, 11))
                : array_map(fn (CarbonImmutable $day) => $day->toDateString(), $this->days($from, $to)),
            'habits' => $rows,
        ];
    }

    /**
     * @return array{0: CarbonImmutable, 1: CarbonImmutable}
     */
    public function bounds(string $range, CarbonImmutable $date): array
    {
        return match ($range) {
            'month' => [$date->startOfMonth(), $date->endOfMonth()->startOfDay()],
            'year' => [$date->startOfYear(), $date->endOfYear()->startOfDay()],
            default => [HabitCalendar::weekStart($date), HabitCalendar::weekEnd($date)],
        };
    }

    /**
     * @param  array<string, Period>  $index
     */
    public function dayState(Timeline $timeline, array $index, CarbonImmutable $day, CarbonImmutable $today): string
    {
        if ($day->lt($timeline->start)) {
            return 'none';
        }

        if ($day->gt($today)) {
            return $timeline->isOnBreak($day) ? 'rest' : 'future';
        }

        $period = $index[$day->toDateString()] ?? null;

        if ($period === null) {
            return 'none';
        }

        if ($period->status === PeriodStatus::Excused || $timeline->isOnBreak($day)) {
            return 'rest';
        }

        if ($period->period === GoalPeriod::Week) {
            $logged = $timeline->valueOn($day) > 0;

            return match (true) {
                $timeline->kind === HabitKind::Avoid => $logged ? 'miss' : ($day->eq($today) ? 'today' : 'done'),
                $logged => 'done',
                $day->eq($today) => $period->isMet() ? 'off' : 'today',
                default => 'off',
            };
        }

        return match ($period->status) {
            PeriodStatus::Met => 'done',
            PeriodStatus::Missed => 'miss',
            PeriodStatus::Current => 'today',
            default => 'off',
        };
    }

    /**
     * @param  list<Period>  $periods
     * @return array<string, Period>
     */
    public function index(array $periods): array
    {
        $index = [];

        foreach ($periods as $period) {
            for ($day = $period->start; $day->lte($period->end); $day = $day->addDay()) {
                $index[$day->toDateString()] = $period;
            }
        }

        return $index;
    }

    /**
     * @return Collection<int, Habit>
     */
    public function habits(User $user, bool $includeInactive = false): Collection
    {
        return Habit::query()->ownedBy($user)
            ->with(['goals', 'entries', 'breaks'])
            ->when(! $includeInactive, fn ($query) => $query->active())
            ->ordered()
            ->get();
    }

    /**
     * @return list<CarbonImmutable>
     */
    private function days(CarbonImmutable $from, CarbonImmutable $to): array
    {
        $days = [];

        for ($day = $from; $day->lte($to); $day = $day->addDay()) {
            $days[] = $day;
        }

        return $days;
    }

    private function previous(string $range, CarbonImmutable $from): CarbonImmutable
    {
        return match ($range) {
            'month' => $from->subMonthNoOverflow(),
            'year' => $from->subYear(),
            default => $from->subWeek(),
        };
    }

    /**
     * @param  list<Period>  $periods
     * @return list<array{month: string, consistency: int|null}>
     */
    private function monthCells(array $periods, CarbonImmutable $from): array
    {
        return array_map(function (int $offset) use ($periods, $from): array {
            $month = $from->addMonths($offset);

            return [
                'month' => $month->format('Y-m'),
                'consistency' => HabitStats::percent(HabitStats::tally($periods, $month->startOfMonth(), $month->endOfMonth()->startOfDay())),
            ];
        }, range(0, 11));
    }

    /**
     * @param  list<Period>  $periods
     * @return array{start: string, value: float, target: float}
     */
    private function weekBar(Timeline $timeline, array $periods, CarbonImmutable $start, CarbonImmutable $today): array
    {
        $end = $start->addDays(6);
        $inWeek = array_values(array_filter($periods, fn (Period $period) => $period->start->gte($start) && $period->end->lte($end)));
        $value = 0.0;
        $target = 0.0;

        foreach ($inWeek as $period) {
            if (in_array($period->status, [PeriodStatus::Off, PeriodStatus::Excused], true)) {
                continue;
            }

            if ($period->period === GoalPeriod::Week || $timeline->kind === HabitKind::Quantity) {
                $value += $period->value;
                $target += $period->target;

                continue;
            }

            $value += $period->isMet() ? 1 : 0;
            $target += $period->end->lte($today) ? 1 : 0;
        }

        return ['start' => $start->toDateString(), 'value' => round($value, 2), 'target' => round($target, 2)];
    }

    private function ratio(HabitKind $kind, Period $period): float
    {
        if ($kind === HabitKind::Avoid) {
            return $period->target <= 0 ? ($period->value > 0 ? 1.0 : 0.0) : min(1.0, $period->value / $period->target);
        }

        return $period->target <= 0 ? 1.0 : min(1.0, $period->value / $period->target);
    }

    /**
     * @return Collection<int, HabitBreak>
     */
    public function globalBreaks(string $userId): Collection
    {
        return HabitBreak::query()->ownedBy($userId)->global()->get();
    }
}
