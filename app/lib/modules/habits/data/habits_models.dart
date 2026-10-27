import 'package:flutter/foundation.dart';

import '../../finance/data/json.dart';

enum HabitKind {
  check('Sí / No'),
  quantity('Cantidad'),
  avoid('Evitar');

  const HabitKind(this.label);

  final String label;

  static HabitKind of(String? value) => values.firstWhere((kind) => kind.name == value, orElse: () => check);
}

enum GoalPeriod {
  day,
  week;

  static GoalPeriod of(String? value) => value == 'week' ? week : day;
}

enum HabitStatus {
  active,
  paused,
  archived;

  static HabitStatus of(String? value) => values.firstWhere((status) => status.name == value, orElse: () => active);
}

/// How a single day looks in the week dots, the calendar and the progress grid.
enum DayState {
  done,
  miss,
  today,
  future,
  off,
  rest,
  none;

  static DayState of(String? value) => values.firstWhere((state) => state.name == value, orElse: () => none);

  String get label => switch (this) {
    done => 'cumplido',
    miss => 'no cumplido',
    today => 'hoy, pendiente',
    future => 'por llegar',
    off => 'no toca',
    rest => 'descanso',
    none => 'sin empezar',
  };
}

double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

@immutable
class HabitGoal {
  const HabitGoal({required this.period, required this.target, this.daysOfWeek, this.validFrom});

  factory HabitGoal.fromJson(Json json) => HabitGoal(
    period: GoalPeriod.of(json['period'] as String?),
    target: _double(json['target']),
    daysOfWeek: (json['days_of_week'] as List?)?.map((day) => (day as num).toInt()).toList(),
    validFrom: parseIsoDateOrNull(json['valid_from']),
  );

  final GoalPeriod period;
  final double target;
  final List<int>? daysOfWeek;
  final DateTime? validFrom;
}

@immutable
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.kind,
    required this.goal,
    required this.goalText,
    required this.startDate,
    this.unit,
    this.showInTasks = true,
    this.sort = 0,
    this.preferredTime,
    this.status = HabitStatus.active,
    this.convertedFromTemplateId,
  });

  factory Habit.fromJson(Json json) => Habit(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    icon: json['icon'] as String? ?? 'check',
    kind: HabitKind.of(json['kind'] as String?),
    unit: json['unit'] as String?,
    showInTasks: json['show_in_tasks'] as bool? ?? true,
    sort: intOf(json['sort']),
    startDate: parseIsoDate(json['start_date'] as String),
    preferredTime: json['preferred_time'] as String?,
    status: HabitStatus.of(json['status'] as String?),
    convertedFromTemplateId: json['converted_from_template_id'] as String?,
    goal: HabitGoal.fromJson(json['goal'] as Json),
    goalText: json['goal_text'] as String? ?? '',
  );

  final String id;
  final String name;
  final String icon;
  final HabitKind kind;
  final String? unit;
  final bool showInTasks;
  final int sort;
  final DateTime startDate;
  final String? preferredTime;
  final HabitStatus status;
  final String? convertedFromTemplateId;
  final HabitGoal goal;
  final String goalText;

  bool get isAvoid => kind == HabitKind.avoid;
}

/// A habit as it stands today: the period in course (day or week), its value and the streak.
@immutable
class HabitToday {
  const HabitToday({
    required this.habit,
    required this.period,
    required this.periodEnd,
    required this.target,
    required this.value,
    required this.todayValue,
    required this.status,
    required this.met,
    required this.over,
    required this.progress,
    required this.daysLeft,
    required this.streak,
    this.todayNote,
    this.consistency,
  });

  factory HabitToday.fromJson(Json json) => HabitToday(
    habit: Habit.fromJson(json),
    period: GoalPeriod.of(json['period'] as String?),
    periodEnd: parseIsoDate(json['period_end'] as String),
    target: _double(json['target']),
    value: _double(json['value']),
    todayValue: _double(json['today_value']),
    todayNote: json['today_note'] as String?,
    status: json['status'] as String? ?? 'current',
    met: json['met'] as bool? ?? false,
    over: json['over'] as bool? ?? false,
    progress: _double(json['progress']),
    daysLeft: intOf(json['days_left']),
    streak: intOf(json['streak']),
    consistency: intOrNull(json['consistency']),
  );

  final Habit habit;
  final GoalPeriod period;
  final DateTime periodEnd;
  final double target;
  final double value;
  final double todayValue;
  final String? todayNote;
  final String status;
  final bool met;
  final bool over;
  final double progress;
  final int daysLeft;
  final int streak;
  final int? consistency;

  String get id => habit.id;
  bool get weekly => period == GoalPeriod.week;
}

@immutable
class HabitsTodayView {
  const HabitsTodayView({
    required this.date,
    required this.habits,
    this.done = 0,
    this.total = 0,
    this.consistency,
    this.onBreak = false,
  });

  factory HabitsTodayView.fromJson(Json json) {
    final summary = json['summary'] as Json? ?? const {};
    return HabitsTodayView(
      date: parseIsoDate(json['date'] as String),
      onBreak: json['on_break'] as bool? ?? false,
      done: intOf(summary['done']),
      total: intOf(summary['total']),
      consistency: intOrNull(summary['consistency']),
      habits: parseList(json['habits'], HabitToday.fromJson),
    );
  }

  final DateTime date;
  final List<HabitToday> habits;
  final int done;
  final int total;
  final int? consistency;
  final bool onBreak;

  List<HabitToday> get pending => [
    for (final habit in habits)
      if (!habit.habit.isAvoid && !habit.met) habit,
  ];

  List<HabitToday> get avoid => [
    for (final habit in habits)
      if (habit.habit.isAvoid) habit,
  ];

  List<HabitToday> get completed => [
    for (final habit in habits)
      if (!habit.habit.isAvoid && habit.met) habit,
  ];
}

@immutable
class DayCell {
  const DayCell(this.date, this.state);

  factory DayCell.fromJson(Json json) =>
      DayCell(parseIsoDate(json['date'] as String), DayState.of(json['state'] as String?));

  final DateTime date;
  final DayState state;
}

@immutable
class HabitListItem {
  const HabitListItem({required this.habit, required this.week, this.consistency, this.streak = 0});

  factory HabitListItem.fromJson(Json json) => HabitListItem(
    habit: Habit.fromJson(json),
    consistency: intOrNull(json['consistency']),
    streak: intOf(json['streak']),
    week: parseList(json['week'], DayCell.fromJson),
  );

  final Habit habit;
  final int? consistency;
  final int streak;
  final List<DayCell> week;
}

@immutable
class WeekBar {
  const WeekBar({required this.start, required this.value, required this.target});

  factory WeekBar.fromJson(Json json) => WeekBar(
    start: parseIsoDate(json['start'] as String),
    value: _double(json['value']),
    target: _double(json['target']),
  );

  final DateTime start;
  final double value;
  final double target;
}

@immutable
class HabitDetail {
  const HabitDetail({
    required this.habit,
    required this.weeks,
    required this.goals,
    this.consistency,
    this.consistencyAll,
    this.streak = 0,
    this.bestStreak = 0,
    this.bestStreakEnd,
    this.today,
  });

  factory HabitDetail.fromJson(Json json) {
    final stats = json['stats'] as Json? ?? const {};
    return HabitDetail(
      habit: Habit.fromJson(json),
      consistency: intOrNull(stats['consistency']),
      consistencyAll: intOrNull(stats['consistency_all']),
      streak: intOf(stats['streak']),
      bestStreak: intOf(stats['best_streak']),
      bestStreakEnd: parseIsoDateOrNull(stats['best_streak_end']),
      goals: parseList(json['goals'], HabitGoal.fromJson),
      weeks: parseList(json['weeks'], WeekBar.fromJson),
      today: json['today'] is Map ? HabitToday.fromJson(json['today'] as Json) : null,
    );
  }

  final Habit habit;
  final int? consistency;
  final int? consistencyAll;
  final int streak;
  final int bestStreak;
  final DateTime? bestStreakEnd;
  final List<HabitGoal> goals;
  final List<WeekBar> weeks;
  final HabitToday? today;
}

@immutable
class CalendarDay {
  const CalendarDay({required this.date, required this.state, this.value = 0, this.note});

  factory CalendarDay.fromJson(Json json) => CalendarDay(
    date: parseIsoDate(json['date'] as String),
    state: DayState.of(json['state'] as String?),
    value: _double(json['value']),
    note: json['note'] as String?,
  );

  final DateTime date;
  final DayState state;
  final double value;
  final String? note;
}

enum ProgressRange {
  week('Semana'),
  month('Mes'),
  year('Año');

  const ProgressRange(this.label);

  final String label;
}

@immutable
class ProgressRow {
  const ProgressRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.cells,
    required this.monthCells,
    this.consistency,
    this.trend,
    this.met = 0,
    this.total = 0,
  });

  factory ProgressRow.fromJson(Json json) {
    final cells = (json['cells'] as List?) ?? const [];
    final byMonth = cells.isNotEmpty && (cells.first as Json).containsKey('month');
    return ProgressRow(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? 'check',
      consistency: intOrNull(json['consistency']),
      trend: intOrNull(json['trend']),
      met: intOf(json['met']),
      total: intOf(json['total']),
      cells: byMonth ? const [] : [for (final cell in cells) DayCell.fromJson(cell as Json)],
      monthCells: byMonth ? [for (final cell in cells) intOrNull((cell as Json)['consistency'])] : const [],
    );
  }

  final String id;
  final String name;
  final String icon;
  final int? consistency;
  final int? trend;
  final int met;
  final int total;
  final List<DayCell> cells;
  final List<int?> monthCells;
}

@immutable
class HabitsProgress {
  const HabitsProgress({
    required this.range,
    required this.from,
    required this.to,
    required this.rows,
    this.consistency,
    this.previousConsistency,
    this.trend,
    this.met = 0,
    this.total = 0,
  });

  factory HabitsProgress.fromJson(Json json) => HabitsProgress(
    range: ProgressRange.values.firstWhere((range) => range.name == json['range'], orElse: () => ProgressRange.week),
    from: parseIsoDate(json['from'] as String),
    to: parseIsoDate(json['to'] as String),
    consistency: intOrNull(json['consistency']),
    previousConsistency: intOrNull(json['previous_consistency']),
    trend: intOrNull(json['trend']),
    met: intOf(json['met']),
    total: intOf(json['total']),
    rows: parseList(json['habits'], ProgressRow.fromJson),
  );

  final ProgressRange range;
  final DateTime from;
  final DateTime to;
  final int? consistency;
  final int? previousConsistency;
  final int? trend;
  final int met;
  final int total;
  final List<ProgressRow> rows;
}

@immutable
class HabitBreak {
  const HabitBreak({
    required this.id,
    required this.from,
    required this.to,
    this.habitId,
    this.active = false,
    this.upcoming = false,
  });

  factory HabitBreak.fromJson(Json json) => HabitBreak(
    id: json['id'] as String,
    habitId: json['habit_id'] as String?,
    from: parseIsoDate(json['from_date'] as String),
    to: parseIsoDate(json['to_date'] as String),
    active: json['active'] as bool? ?? false,
    upcoming: json['upcoming'] as bool? ?? false,
  );

  final String id;
  final String? habitId;
  final DateTime from;
  final DateTime to;
  final bool active;
  final bool upcoming;

  bool get global => habitId == null;
}

@immutable
class ConversionPreview {
  const ConversionPreview({
    required this.templateId,
    required this.name,
    required this.goalText,
    required this.cells,
    this.done = 0,
    this.skipped = 0,
    this.missed = 0,
    this.consistency,
    this.streak = 0,
  });

  factory ConversionPreview.fromJson(Json json) => ConversionPreview(
    templateId: json['template_id'] as String,
    name: json['name'] as String? ?? '',
    goalText: json['goal_text'] as String? ?? '',
    done: intOf(json['done']),
    skipped: intOf(json['skipped']),
    missed: intOf(json['missed']),
    consistency: intOrNull(json['consistency']),
    streak: intOf(json['streak']),
    cells: parseList(json['cells'], DayCell.fromJson),
  );

  final String templateId;
  final String name;
  final String goalText;
  final int done;
  final int skipped;
  final int missed;
  final int? consistency;
  final int streak;
  final List<DayCell> cells;
}

@immutable
class HabitsSettings {
  const HabitsSettings({this.showInTasks = true, this.digest = true});

  factory HabitsSettings.fromJson(Map<String, dynamic> json) =>
      HabitsSettings(showInTasks: json['show_in_tasks'] as bool? ?? true, digest: json['digest'] as bool? ?? true);

  final bool showInTasks;
  final bool digest;
}
