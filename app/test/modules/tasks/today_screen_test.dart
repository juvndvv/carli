import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/tasks/data/tasks_models.dart';
import 'package:carli/modules/tasks/screens/today_screen.dart';
import 'package:carli/modules/tasks/ui/tasks_home_card.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import 'tasks_fixtures.dart';

Map<String, FakeRoute> _routes({required List<String> completed, required List<String> reopened}) => {
  'GET /v1/modules': (_) => (200, {'data': <Object>[]}),
  'GET /v1/pending/summary': (_) => (
    200,
    {
      'data': {'total': 0, 'by_module': <Object>[]},
    },
  ),
  'GET /v1/tasks/today': (_) => (
    200,
    todayJson(
      overdue: [taskJson(id: 'late', title: 'Llamar al seguro', dueDate: isoDate(DateTime.now().subtract(const Duration(days: 1))), overdue: true)],
      today: [
        taskJson(
          id: 'trash',
          title: 'Sacar la basura',
          dueTime: '21:00',
          template: {
            'id': 'tpl-1',
            'title': 'Sacar la basura',
            'frequency_text': 'Cada lunes y jueves',
            'paused': false,
          },
        ),
        taskJson(id: 'gift', title: 'Comprar regalo', important: true),
      ],
      done: [taskJson(id: 'done', title: 'Revisar extracto', status: 'done')],
    ),
  ),
  'POST /v1/tasks/tasks/gift/complete': (_) {
    completed.add('gift');
    return (200, {'data': taskJson(id: 'gift', title: 'Comprar regalo', status: 'done')});
  },
  'POST /v1/tasks/tasks/gift/reopen': (_) {
    reopened.add('gift');
    return (200, {'data': taskJson(id: 'gift', title: 'Comprar regalo')});
  },
};

void main() {
  testWidgets('groups overdue, today and done with the day progress', (tester) async {
    await pumpFinance(tester, const TodayScreen(), FakeApi(_routes(completed: [], reopened: [])));

    expect(find.text('Lunes, 26 de octubre'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('1 vencida'), findsOneWidget);
    expect(find.text('Vencidas'), findsOneWidget);
    expect(find.text('Llamar al seguro'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('Bandeja · 21:00'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Se repite')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Importante')), findsOneWidget);
    expect(find.text('Hechas hoy · 1'), findsOneWidget);
    expect(find.text('Revisar extracto'), findsNothing);

    await tester.tap(find.text('Hechas hoy · 1'));
    await settle(tester);
    expect(find.text('Revisar extracto'), findsOneWidget);
  });

  testWidgets('completes a task with one tap and undoes it from the toast', (tester) async {
    final completed = <String>[];
    final reopened = <String>[];
    await pumpFinance(tester, const TodayScreen(), FakeApi(_routes(completed: completed, reopened: reopened)));

    await tester.tap(find.bySemanticsLabel('Marcar Comprar regalo como hecha'));
    await settle(tester);

    expect(completed, ['gift']);
    expect(find.text('Comprar regalo hecha'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(reopened, ['gift']);
    await tester.pump(const Duration(seconds: 5));
  });

  test('summarises the day for the home card', () {
    final view = TodayView.fromJson(
      todayJson(
            overdue: [taskJson(id: 'late', overdue: true)],
            today: [
              taskJson(id: 'a'),
              taskJson(id: 'b'),
            ],
          )['data']
          as Map<String, dynamic>,
    );
    expect(tasksHomeHeadline(view), '2 tareas para hoy · 1 vencida');
    expect(
      tasksHomeHeadline(
        TodayView.fromJson(todayJson(done: [taskJson(status: 'done')])['data'] as Map<String, dynamic>),
      ),
      'Todo hecho por hoy',
    );
  });
}
