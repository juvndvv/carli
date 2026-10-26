import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/pending/pending_models.dart';
import 'package:carli/modules/tasks/ui/tasks_pending.dart';
import 'package:carli/shell/app_shell.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import 'tasks_fixtures.dart';

void main() {
  test('opens the tasks tab bar inside /tareas', () {
    expect(shellContextFor('/tareas/hoy'), ShellContext.tasks);
    expect(shellContextFor('/tareas/listas/abc'), ShellContext.tasks);
    expect(shellContextFor('/finanzas'), ShellContext.finance);
    expect(shellContextFor('/'), ShellContext.home);
    expect(
      [for (final destination in tasksDestinations) destination.label],
      ['Hoy', 'Próximas', 'Listas', 'Plantillas'],
    );
  });

  testWidgets('resolves an overdue task from Pendientes with one tap', (tester) async {
    final calls = <String>[];
    PendingItem? resolved;
    final api = FakeApi({
      'POST /v1/tasks/tasks/late/postpone': (options) {
        calls.add('postpone ${(options.data as Map)['date']}');
        return (200, {'data': taskJson(id: 'late')});
      },
    });
    final item = PendingItem(
      module: 'tasks',
      type: TasksPendingTypes.overdue,
      id: 'late',
      title: 'Llamar al seguro',
      date: DateTime(2026, 10, 25),
      route: '/tareas/hoy',
      meta: const {'task_id': 'late'},
    );
    await pumpFinance(
      tester,
      Scaffold(
        body: OverdueTaskPendingAction(item: item, onResolved: (item) => resolved = item),
      ),
      api,
    );

    expect(find.text('Hecha'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);

    await tester.tap(find.text('Pasar a hoy'));
    await settle(tester);

    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    expect(calls, ['postpone $today']);
    expect(resolved, item);
    expect(find.text('Llamar al seguro pasa a hoy'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
