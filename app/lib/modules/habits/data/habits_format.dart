import '../../../core/format/dates.dart';
import 'habits_models.dart';

String habitNumber(double value) {
  if ((value - value.roundToDouble()).abs() < 0.005) return value.round().toString();
  var text = value.toStringAsFixed(2).replaceAll('.', ',');
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.endsWith(',') ? text.substring(0, text.length - 1) : text;
}

String habitAmount(double value, String? unit) {
  final trimmed = unit?.trim() ?? '';
  return trimmed.isEmpty ? habitNumber(value) : '${habitNumber(value)} $trimmed';
}

String habitValueLabel(HabitToday today) {
  final habit = today.habit;
  return switch (habit.kind) {
    HabitKind.check when today.weekly => '${habitNumber(today.value)} de ${habitNumber(today.target)}',
    HabitKind.check => today.met ? 'Hecho' : 'Sin hacer',
    HabitKind.quantity => '${habitNumber(today.value)} / ${habitAmount(today.target, habit.unit)}',
    HabitKind.avoid when today.target <= 0 => today.value > 0 ? 'Recaída' : habitCleanLabel(today.streak, today.period),
    HabitKind.avoid =>
      '${habitNumber(today.value)} de ${habitAmount(today.target, habit.unit)}${today.over ? ' · pasado' : ''}',
  };
}

String habitCleanLabel(int streak, GoalPeriod period) => switch ((streak, period)) {
  (1, GoalPeriod.day) => '1 día sin',
  (_, GoalPeriod.day) => '$streak días sin',
  (1, GoalPeriod.week) => '1 semana sin',
  _ => '$streak semanas sin',
};

String habitStreakLabel(int streak, GoalPeriod period) =>
    period == GoalPeriod.week ? 'Racha $streak sem' : 'Racha $streak';

String habitStreakLength(int streak, GoalPeriod period) => switch ((streak, period)) {
  (1, GoalPeriod.day) => '1 día',
  (_, GoalPeriod.day) => '$streak días',
  (1, GoalPeriod.week) => '1 semana',
  _ => '$streak semanas',
};

String habitGoalLine(HabitToday today) {
  if (today.weekly && today.met) return 'Hecho esta semana';
  if (today.weekly && today.daysLeft > 0) {
    return '${today.habit.goalText} · ${today.daysLeft == 1 ? 'queda 1 día' : 'quedan ${today.daysLeft} días'}';
  }
  return today.habit.goalText;
}

String habitPercent(int? value) => value == null ? '—' : '$value %';

String habitTrend(int? trend) => switch (trend) {
  null => '',
  0 => '=',
  > 0 => '↑ $trend',
  _ => '↓ ${-trend}',
};

String habitSince(DateTime start) => 'desde el ${start.day} de ${monthsLong[start.month - 1]}';

/// ISO week number (weeks start on Monday, week 1 holds the first Thursday).
int isoWeek(DateTime date) {
  final day = dateOnly(date);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekThursday = firstThursday.add(Duration(days: 4 - firstThursday.weekday));
  return 1 + daysBetween(firstWeekThursday, thursday) ~/ 7;
}
