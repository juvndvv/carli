import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/modules/tasks/screens/template_editor_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/routed_app.dart';
import 'tasks_fixtures.dart';

Map<String, dynamic> _body(Object? data) =>
    data is String ? jsonDecode(data) as Map<String, dynamic> : Map<String, dynamic>.from(data! as Map);

void main() {
  testWidgets('previews the next dates and saves a weekly template', (tester) async {
    final previews = <Map<String, dynamic>>[];
    Map<String, dynamic>? saved;
    final api = FakeApi({
      'GET /v1/modules': (_) => (200, {'data': <Object>[]}),
      'GET /v1/pending/summary': (_) => (
        200,
        {
          'data': {'total': 0, 'by_module': <Object>[]},
        },
      ),
      'GET /v1/tasks/lists': (_) => (
        200,
        {
          'data': [
            {...taskListRefJson(), 'archived': false, 'open_tasks_count': 0, 'sort_order': 0},
          ],
        },
      ),
      'POST /v1/tasks/templates/preview': (options) {
        previews.add(_body(options.data));
        return (200, previewJson(dates: ['2026-10-29', '2026-11-02']));
      },
      'POST /v1/tasks/templates': (options) {
        saved = _body(options.data);
        return (201, {'data': templateJson()});
      },
    });
    await pumpRouted(
      tester,
      api,
      initialLocation: '/inicio',
      routes: [
        visitedRoute('/inicio'),
        GoRoute(
          path: '/nueva',
          builder: (context, state) => const TemplateEditorScreen(seed: TemplateSeed(title: 'Sacar la basura')),
        ),
      ],
    );
    GoRouter.of(tester.element(find.text('Visited /inicio'))).push('/nueva');
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('Cada lunes y jueves'), findsOneWidget);
    expect(find.text('jue 29 oct'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('jueves'));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(previews.last['rrule'], contains('BYDAY='));
    expect(previews.last['rrule'], contains('TH'));

    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(saved?['title'], 'Sacar la basura');
    expect(saved?['rrule'], previews.last['rrule']);
    expect(saved?['policy'], 'replace');
    expect(saved?.containsKey('apply_to_open'), isFalse);
    expect(find.text('Visited /inicio'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
