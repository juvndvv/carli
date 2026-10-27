import 'package:carli/modules/finance/data/json.dart';

Json habitJson({
  String id = 'meditate',
  String name = 'Meditar',
  String icon = 'leaf',
  String kind = 'check',
  String? unit,
  String period = 'day',
  num target = 1,
  List<int>? days,
  String goalText = 'Cada día',
  bool showInTasks = true,
  String status = 'active',
}) => {
  'id': id,
  'name': name,
  'icon': icon,
  'kind': kind,
  'unit': unit,
  'show_in_tasks': showInTasks,
  'sort': 0,
  'start_date': '2026-09-01',
  'preferred_time': null,
  'status': status,
  'paused_at': null,
  'archived_at': null,
  'converted_from_template_id': null,
  'goal': {'period': period, 'target': target, 'days_of_week': days, 'valid_from': '2026-09-01'},
  'goal_text': goalText,
};

Json habitTodayJson(
  Json habit, {
  num value = 0,
  num? todayValue,
  bool met = false,
  bool over = false,
  String status = 'current',
  num? target,
  int streak = 3,
  int daysLeft = 1,
  String periodEnd = '2026-10-27',
}) {
  final goal = habit['goal'] as Json;
  final goalTarget = target ?? goal['target'] as num;
  return {
    ...habit,
    'period': goal['period'],
    'period_start': '2026-10-27',
    'period_end': periodEnd,
    'target': goalTarget,
    'value': value,
    'today_value': todayValue ?? value,
    'today_note': null,
    'status': status,
    'met': met,
    'over': over,
    'progress': goalTarget == 0 ? 0 : (value / goalTarget).clamp(0, 1),
    'days_left': daysLeft,
    'streak': streak,
    'streak_unit': goal['period'],
    'consistency': 80,
  };
}

Json todayViewJson(List<Json> habits, {int done = 1, int total = 2, bool onBreak = false}) => {
  'data': {
    'date': '2026-10-27',
    'on_break': onBreak,
    'summary': {'done': done, 'total': total, 'consistency': 86},
    'habits': habits,
  },
};

Json moduleJson(String id, {bool enabled = true, Json settings = const {}}) => {
  'id': id,
  'name': id,
  'icon': 'repeat',
  'route': '/$id',
  'available': true,
  'coming_soon': false,
  'enabled': enabled,
  'settings': settings,
};

final meditateToday = habitTodayJson(habitJson(), streak: 12);
final waterToday = habitTodayJson(
  habitJson(
    id: 'water',
    name: 'Agua',
    icon: 'droplet',
    kind: 'quantity',
    unit: 'vasos',
    target: 8,
    goalText: '8 vasos al día',
  ),
  value: 5,
  streak: 4,
);
final runToday = habitTodayJson(
  habitJson(id: 'run', name: 'Correr', icon: 'running', period: 'week', target: 3, goalText: '3 veces por semana'),
  value: 3,
  todayValue: 0,
  met: true,
  status: 'met',
  periodEnd: '2026-11-01',
  daysLeft: 6,
  streak: 5,
);
final coffeeToday = habitTodayJson(
  habitJson(
    id: 'coffee',
    name: 'Café',
    icon: 'coffee',
    kind: 'avoid',
    unit: 'cafés',
    target: 2,
    goalText: 'Máximo 2 cafés al día',
  ),
  value: 1,
);
