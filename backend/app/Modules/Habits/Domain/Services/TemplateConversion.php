<?php

namespace App\Modules\Habits\Domain\Services;

use App\Core\Recurrence\RecurrenceRule;
use App\Models\User;
use App\Modules\Habits\Domain\Enums\EntrySource;
use App\Modules\Habits\Domain\Enums\GoalPeriod;
use App\Modules\Habits\Domain\Enums\HabitKind;
use App\Modules\Habits\Domain\Evaluation\Goal;
use App\Modules\Habits\Domain\Evaluation\HabitEvaluator;
use App\Modules\Habits\Domain\Evaluation\HabitStats;
use App\Modules\Habits\Domain\Evaluation\Timeline;
use App\Modules\Habits\Domain\Support\GoalDescriber;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Habits\Domain\Support\HabitIcons;
use App\Modules\Habits\Models\Habit;
use App\Modules\Tasks\Domain\Conversion\TemplateHistory;
use App\Modules\Tasks\Domain\Conversion\TemplateHistoryReader;
use App\Modules\Tasks\Domain\Services\TemplateService;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final readonly class TemplateConversion
{
    public const int PREVIEW_WEEKS = 8;

    private const array WEEKDAYS = ['MO' => 1, 'TU' => 2, 'WE' => 3, 'TH' => 4, 'FR' => 5, 'SA' => 6, 'SU' => 7];

    public function __construct(
        private TemplateHistoryReader $reader,
        private TemplateService $templates,
        private HabitService $habits,
        private EntryService $entries,
        private BreakService $breaks,
        private HabitEvaluator $evaluator,
        private HabitReport $report,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function preview(User $user, string $templateId): array
    {
        $history = $this->history($user, $templateId);
        $goal = $this->goal($history);
        $today = HabitCalendar::today();
        $timeline = $this->timeline($history, $goal, $today);
        $periods = $this->evaluator->periods($timeline, $today);
        $index = $this->report->index($periods);
        $from = HabitCalendar::weekStart($today)->subWeeks(self::PREVIEW_WEEKS - 1);
        $counts = array_count_values($history->occurrences);

        $cells = [];
        for ($day = $from; $day->lte(HabitCalendar::weekEnd($today)); $day = $day->addDay()) {
            $cells[] = ['date' => $day->toDateString(), 'state' => $this->report->dayState($timeline, $index, $day, $today)];
        }

        return [
            'template_id' => $history->templateId,
            'name' => $history->title,
            'kind' => HabitKind::Check->value,
            'start_date' => $timeline->start->toDateString(),
            'goal' => ['period' => $goal->period->value, 'target' => $goal->target, 'days_of_week' => $goal->daysOfWeek],
            'goal_text' => GoalDescriber::describe(HabitKind::Check, null, $goal),
            'done' => $counts[TemplateHistory::DONE] ?? 0,
            'skipped' => $counts[TemplateHistory::SKIPPED] ?? 0,
            'missed' => $counts[TemplateHistory::MISSED] ?? 0,
            'consistency' => HabitStats::consistency($periods, $today),
            'streak' => HabitStats::streak($periods),
            'cells' => $cells,
        ];
    }

    /**
     * @param  array{name?: string|null, icon?: string|null, show_in_tasks?: bool|null}  $overrides
     */
    public function convert(User $user, string $templateId, array $overrides = []): Habit
    {
        $history = $this->history($user, $templateId);
        $goal = $this->goal($history);
        $today = HabitCalendar::today();
        $start = $this->start($history, $today);

        return DB::transaction(function () use ($user, $history, $goal, $start, $overrides): Habit {
            $habit = $this->habits->create($user, [
                'name' => $overrides['name'] ?? $history->title,
                'icon' => $overrides['icon'] ?? HabitIcons::DEFAULT,
                'kind' => HabitKind::Check->value,
                'show_in_tasks' => $overrides['show_in_tasks'] ?? true,
                'start_date' => $start->toDateString(),
                'period' => $goal->period->value,
                'target' => 1,
                'days_of_week' => $goal->daysOfWeek,
                'converted_from_template_id' => $history->templateId,
            ]);

            foreach ($history->occurrences as $date => $status) {
                if ($status === TemplateHistory::DONE) {
                    $this->entries->set($habit, HabitCalendar::date($date), 1.0, source: EntrySource::TaskImport);
                }
            }

            foreach ($this->skippedRanges($history) as [$from, $to]) {
                $this->breaks->create($user, ['habit_id' => $habit->id, 'from_date' => $from, 'to_date' => $to]);
            }

            $this->templates->retire($user, $history->templateId);

            return $habit->load(['goals', 'entries', 'breaks']);
        });
    }

    public function goal(TemplateHistory $history): Goal
    {
        $goal = $history->afterDone || $history->rrule === null ? null : $this->goalFromRule($history);

        if ($goal === null) {
            throw ValidationException::withMessages(['template_id' => 'Solo se pueden convertir plantillas que se repiten cada día o ciertos días de la semana.']);
        }

        return $goal;
    }

    private function goalFromRule(TemplateHistory $history): ?Goal
    {
        try {
            $rule = RecurrenceRule::parse((string) $history->rrule, $history->dtstart);
        } catch (InvalidArgumentException) {
            return null;
        }

        if ($rule->interval() !== 1 || ! in_array($rule->frequency(), ['DAILY', 'WEEKLY'], true)) {
            return null;
        }

        foreach (['BYMONTHDAY', 'BYMONTH', 'BYSETPOS'] as $part) {
            if ($rule->part($part) !== null) {
                return null;
            }
        }

        $byDay = $rule->part('BYDAY');
        $days = [];

        foreach ($byDay === null ? [] : explode(',', $byDay) as $code) {
            if (! isset(self::WEEKDAYS[$code])) {
                return null;
            }

            $days[] = self::WEEKDAYS[$code];
        }

        if ($days === [] && $rule->frequency() === 'WEEKLY') {
            $days = [$history->dtstart->dayOfWeekIso];
        }

        sort($days);
        $days = array_values(array_unique($days));

        return new Goal(HabitCalendar::today(), GoalPeriod::Day, 1.0, $days === [] || count($days) === 7 ? null : $days);
    }

    private function history(User $user, string $templateId): TemplateHistory
    {
        return $this->reader->read($user, $templateId) ?? throw new NotFoundHttpException('Plantilla no encontrada.');
    }

    private function start(TemplateHistory $history, CarbonImmutable $today): CarbonImmutable
    {
        $first = $history->firstDate();

        return $first === null ? $today : HabitCalendar::date($first)->min($today);
    }

    private function timeline(TemplateHistory $history, Goal $goal, CarbonImmutable $today): Timeline
    {
        $start = $this->start($history, $today);
        $values = array_map(fn () => 1.0, array_filter($history->occurrences, fn (string $status) => $status === TemplateHistory::DONE));
        $breaks = array_map(fn (array $range) => [HabitCalendar::date($range[0]), HabitCalendar::date($range[1])], $this->skippedRanges($history));

        return new Timeline(HabitKind::Check, $start, null, [new Goal($start, $goal->period, $goal->target, $goal->daysOfWeek)], $values, $breaks);
    }

    /**
     * @return list<array{0: string, 1: string}>
     */
    private function skippedRanges(TemplateHistory $history): array
    {
        $ranges = [];

        foreach ($history->occurrences as $date => $status) {
            if ($status !== TemplateHistory::SKIPPED) {
                continue;
            }

            $last = array_key_last($ranges);

            if ($last !== null && HabitCalendar::date($ranges[$last][1])->addDay()->toDateString() === $date) {
                $ranges[$last][1] = $date;
            } else {
                $ranges[] = [$date, $date];
            }
        }

        return $ranges;
    }
}
