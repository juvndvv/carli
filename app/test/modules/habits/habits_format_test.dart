import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/habits/data/habits_format.dart';
import 'package:carli/modules/habits/data/habits_models.dart';
import 'package:carli/modules/habits/ui/convert_template_sheet.dart';
import 'package:carli/shell/app_shell.dart';

import 'habits_fixtures.dart';

void main() {
  test('opens the habits tab bar inside /habitos', () {
    expect(shellContextFor('/habitos/hoy'), ShellContext.habits);
    expect(shellContextFor('/habitos/progreso'), ShellContext.habits);
    expect(shellContextFor('/tareas/hoy'), ShellContext.tasks);
  });

  test('formats amounts like the backend', () {
    expect(habitNumber(8), '8');
    expect(habitNumber(2.5), '2,5');
    expect(habitNumber(85.71), '85,71');
    expect(habitAmount(150, 'min'), '150 min');
    expect(habitAmount(3, null), '3');
  });

  test('labels the value of each kind of habit', () {
    expect(habitValueLabel(HabitToday.fromJson(meditateToday)), 'Sin hacer');
    expect(habitValueLabel(HabitToday.fromJson(waterToday)), '5 / 8 vasos');
    expect(habitValueLabel(HabitToday.fromJson(runToday)), '3 de 3');
    expect(habitValueLabel(HabitToday.fromJson(coffeeToday)), '1 de 2 cafés');
    expect(
      habitValueLabel(
        HabitToday.fromJson(habitTodayJson(habitJson(kind: 'avoid', target: 0, goalText: 'Nada'), streak: 12)),
      ),
      '12 días sin',
    );
    expect(habitGoalLine(HabitToday.fromJson(runToday)), 'Hecho esta semana');
    expect(
      habitGoalLine(
        HabitToday.fromJson(
          habitTodayJson(habitJson(period: 'week', target: 3, goalText: '3 veces por semana'), daysLeft: 6),
        ),
      ),
      '3 veces por semana · quedan 6 días',
    );
    expect(habitStreakLabel(5, GoalPeriod.week), 'Racha 5 sem');
    expect(habitTrend(4), '↑ 4');
    expect(habitTrend(-11), '↓ 11');
    expect(habitTrend(0), '=');
  });

  test('numbers weeks the ISO way', () {
    expect(isoWeek(DateTime(2026, 10, 27)), 44);
    expect(isoWeek(DateTime(2026, 1, 1)), 1);
    expect(isoWeek(DateTime(2027, 1, 1)), 53);
  });

  test('offers the conversion only for daily or weekly templates', () {
    expect(canConvertToHabit(rrule: 'FREQ=DAILY'), isTrue);
    expect(canConvertToHabit(rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR'), isTrue);
    expect(canConvertToHabit(rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO'), isFalse);
    expect(canConvertToHabit(rrule: 'FREQ=MONTHLY;BYMONTHDAY=1'), isFalse);
    expect(canConvertToHabit(rrule: null), isFalse);
  });
}
