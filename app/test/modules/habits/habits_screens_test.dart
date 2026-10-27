import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/habits/screens/habits_list_screen.dart';
import 'package:carli/modules/habits/screens/habits_progress_screen.dart';
import 'package:carli/modules/habits/screens/habits_today_screen.dart';
import 'package:carli/modules/tasks/screens/today_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../tasks/tasks_fixtures.dart';
import 'habits_fixtures.dart';

void main() {
  testWidgets('groups today in to do, avoid and done with the day ring', (tester) async {
    await pumpFinance(
      tester,
      const HabitsTodayScreen(),
      FakeApi({
        'GET /v1/habits/today': (_) => (200, todayViewJson([meditateToday, waterToday, runToday, coffeeToday])),
      }),
    );

    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('86 %'), findsOneWidget);
    expect(find.text('Por hacer'), findsOneWidget);
    expect(find.text('Meditar'), findsOneWidget);
    expect(find.text('5 / 8 vasos'), findsOneWidget);
    expect(find.text('Racha 12'), findsOneWidget);
    expect(find.text('Evitar'), findsOneWidget);
    expect(find.text('1 de 2 cafés'), findsOneWidget);
    expect(find.text('+1 café'), findsOneWidget);
    expect(find.text('Hechos'), findsOneWidget);
    expect(find.text('Hecho esta semana'), findsOneWidget);
  });

  testWidgets('logs with one tap on the ring and undoes it from the toast', (tester) async {
    final logged = <Object?>[];
    await pumpFinance(
      tester,
      const HabitsTodayScreen(),
      FakeApi({
        'GET /v1/habits/today': (_) => (200, todayViewJson([meditateToday, waterToday])),
        'PUT /v1/habits/meditate/entries/${_today()}': (options) {
          logged.add((options.data as Map)['value']);
          return (
            200,
            {
              'data': {'entry': null, 'today': null},
            },
          );
        },
        'PUT /v1/habits/water/entries/${_today()}': (options) {
          logged.add((options.data as Map)['value']);
          return (
            200,
            {
              'data': {'entry': null, 'today': null},
            },
          );
        },
      }),
    );

    await tester.tap(find.bySemanticsLabel(RegExp('^Registrar Meditar')));
    await settle(tester);
    expect(logged, [1.0]);
    expect(find.text('Meditar: hecho'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(logged, [1.0, 0.0]);

    await tester.tap(find.bySemanticsLabel(RegExp('^Registrar Agua')));
    await settle(tester);
    expect(logged, [1.0, 0.0, 6.0]);
    expect(find.text('Agua: 6 vasos'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('lists habits with the week in seven dots and folds paused ones', (tester) async {
    Map<String, Object?> item(Map<String, Object?> habit, int? consistency, List<String> week) => {
      ...habit,
      'consistency': consistency,
      'streak': 2,
      'streak_unit': 'day',
      'week': [
        for (final (index, state) in week.indexed) {'date': '2026-10-${26 + index}', 'state': state},
      ],
    };
    final week = ['done', 'today', 'future', 'future', 'future', 'future', 'future'];
    await pumpFinance(
      tester,
      const HabitsListScreen(),
      FakeApi({
        'GET /v1/habits': (_) => (
          200,
          {
            'data': [
              item(habitJson(), 89, week),
              item(habitJson(id: 'coffee', name: 'Café', kind: 'avoid', goalText: 'Máximo 2 al día'), 64, week),
              item(habitJson(id: 'english', name: 'Inglés', status: 'paused'), null, week),
            ],
          },
        ),
      }),
    );

    expect(find.textContaining('2 ACTIVOS · SEMANA'), findsOneWidget);
    expect(find.text('89 %'), findsOneWidget);
    expect(find.text('Evitar · máximo 2 al día'), findsOneWidget);
    expect(find.text('Pausados · 1'), findsOneWidget);
    expect(find.text('Inglés'), findsNothing);

    await tester.tap(find.text('Pausados · 1'));
    await settle(tester);
    expect(find.text('Inglés'), findsOneWidget);
  });

  testWidgets('shows global consistency, the grid and the ranking with trends', (tester) async {
    Map<String, Object?> row(String id, String name, int consistency, int? trend) => {
      'id': id,
      'name': name,
      'icon': 'check',
      'kind': 'check',
      'paused': false,
      'consistency': consistency,
      'met': 5,
      'total': 7,
      'trend': trend,
      'cells': [
        for (var day = 0; day < 7; day++) {'date': '2026-10-${26 + day}', 'state': day < 2 ? 'done' : 'future'},
      ],
    };
    await pumpFinance(
      tester,
      const HabitsProgressScreen(),
      FakeApi({
        'GET /v1/habits/progress': (_) => (
          200,
          {
            'data': {
              'range': 'week',
              'from': '2026-10-26',
              'to': '2026-11-01',
              'consistency': 84,
              'met': 41,
              'total': 49,
              'previous_consistency': 78,
              'trend': 6,
              'columns': <String>[],
              'habits': [row('a', 'Meditar', 89, 7), row('b', 'Inglés', 96, 4)],
            },
          },
        ),
      }),
    );

    expect(find.text('84 %'), findsOneWidget);
    expect(find.text('↑ 6 puntos frente a la semana anterior'), findsOneWidget);
    expect(find.text('41 de 49 periodos cumplidos'), findsOneWidget);
    expect(find.text('Por constancia'), findsOneWidget);
    expect(find.text('↑ 7'), findsOneWidget);
    final english = tester.getTopLeft(find.text('96 %'));
    final meditate = tester.getTopLeft(find.text('89 %'));
    expect(english.dy, lessThan(meditate.dy));
  });

  testWidgets('adds a ring row to Tareas · Hoy without counting habits as tasks', (tester) async {
    await pumpFinance(
      tester,
      const TodayScreen(),
      FakeApi({
        'GET /v1/modules': (_) => (
          200,
          {
            'data': [
              moduleJson('tasks'),
              moduleJson('habits', settings: {'show_in_tasks': true}),
            ],
          },
        ),
        'GET /v1/pending/summary': (_) => (
          200,
          {
            'data': {'total': 0, 'by_module': <Object>[]},
          },
        ),
        'GET /v1/tasks/today': (_) => (
          200,
          todayJson(
            today: [taskJson(id: 'gift', title: 'Comprar regalo')],
          ),
        ),
        'GET /v1/habits/today': (_) => (200, todayViewJson([meditateToday, coffeeToday, runToday])),
      }),
    );

    expect(find.text('0 de 1'), findsOneWidget);
    expect(find.text('Hábitos · queda 1', findRichText: true), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Meditar, Sin hacer')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Café')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Correr')), findsNothing);
  });

  testWidgets('hides the ring row when habits are switched off for Tareas', (tester) async {
    await pumpFinance(
      tester,
      const TodayScreen(),
      FakeApi({
        'GET /v1/modules': (_) => (
          200,
          {
            'data': [
              moduleJson('tasks'),
              moduleJson('habits', settings: {'show_in_tasks': false}),
            ],
          },
        ),
        'GET /v1/pending/summary': (_) => (
          200,
          {
            'data': {'total': 0, 'by_module': <Object>[]},
          },
        ),
        'GET /v1/tasks/today': (_) => (
          200,
          todayJson(
            today: [taskJson(id: 'gift', title: 'Comprar regalo')],
          ),
        ),
        'GET /v1/habits/today': (_) => (200, todayViewJson([meditateToday])),
      }),
    );

    expect(find.textContaining('Hábitos', findRichText: true), findsNothing);
  });
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
