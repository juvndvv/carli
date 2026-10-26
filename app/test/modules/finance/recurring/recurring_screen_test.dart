import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/screens/recurring/recurring_screen.dart';
import 'package:carli/ui/button.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';
import 'recurring_fixtures.dart';

const nbsp = '\u00a0';
const _rulesPath = 'GET /v1/finance/recurring-rules';

final _rules = [
  recurringRuleJson(),
  recurringRuleJson(
    id: 'spotify',
    name: 'Spotify',
    amount: -1199,
    mode: 'auto',
    pending: {'id': 'tx-sp', 'date': '2026-10-23', 'amount_cents': -1199},
  ),
  recurringRuleJson(
    id: 'salary',
    name: 'Nómina Acme S.L.',
    kind: 'income',
    amount: 265000,
    isSubscription: false,
    category: null,
  ),
  recurringRuleJson(id: 'gym', name: 'Gimnasio', cancelled: true),
];

Finder _iconButton(String label) =>
    find.byWidgetPredicate((widget) => widget is CarliButton && widget.semanticLabel == label);

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await settle(tester);
}

void main() {
  testWidgets('shows subscription totals, the reminder and active rules', (tester) async {
    final api = FakeApi({...financeBaseRoutes(), _rulesPath: (_) => (200, recurringIndex(_rules))});
    await pumpFinance(tester, const RecurringScreen(), api);

    expect(api.requests.firstWhere((r) => r.path == '/v1/finance/recurring-rules').queryParameters, {
      'include_cancelled': '1',
    });
    expect(find.text('Suscripciones al mes'), findsOneWidget);
    expect(find.text('−25,98$nbsp€'), findsOneWidget);
    expect(find.text('2 activas'), findsOneWidget);
    expect(find.text('−311,76$nbsp€'), findsOneWidget);
    expect(find.text('2 días antes'), findsOneWidget);

    expect(find.text('Mensual · día 27 · próximo 27 oct'), findsNWidgets(2));
    expect(find.text('Mensual · día 27 · pendiente del 23 oct'), findsOneWidget);
    expect(find.text('−13,99$nbsp€'), findsOneWidget);
    expect(find.text('+2.650,00$nbsp€'), findsOneWidget);
    expect(find.text('Suscripción'), findsNWidgets(2));
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Gimnasio'), findsNothing);
    expect(_iconButton('Confirmar cargo de Spotify'), findsOneWidget);
  });

  testWidgets('switches to pending and cancelled tabs', (tester) async {
    final api = FakeApi({...financeBaseRoutes(), _rulesPath: (_) => (200, recurringIndex(_rules))});
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, find.text('Pendientes de confirmar (1)'));
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);

    await _tapAndSettle(tester, find.text('Canceladas'));
    expect(find.text('Gimnasio'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Spotify'), findsNothing);
  });

  testWidgets('explains the section when there are no rules yet', (tester) async {
    final api = FakeApi({...financeBaseRoutes(), _rulesPath: (_) => (200, recurringIndex(const []))});
    await pumpFinance(tester, const RecurringScreen(), api);

    expect(find.text('Aún no tienes recurrentes'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Pendientes de confirmar'));
    expect(find.text('Nada pendiente de confirmar'), findsOneWidget);
  });

  testWidgets('shows upcoming subscription charges on the subscriptions tab', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 5));
    final iso = '${soon.year}-${soon.month.toString().padLeft(2, '0')}-${soon.day.toString().padLeft(2, '0')}';
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => (200, recurringIndex([recurringRuleJson(nextOccurrence: iso)])),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    expect(find.text('Próximos cargos'), findsNothing);
    await _tapAndSettle(tester, find.text('Suscripciones'));
    expect(find.text('Próximos cargos'), findsOneWidget);
    expect(find.textContaining('en 5 días · Cuenta corriente'), findsOneWidget);
  });

  testWidgets('offers a retry when the list fails to load', (tester) async {
    var fail = true;
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => fail ? (500, {'message': 'boom'}) : (200, recurringIndex(_rules)),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    expect(find.text('No se han podido cargar'), findsOneWidget);
    fail = false;
    await _tapAndSettle(tester, find.text('Reintentar'));
    expect(find.text('Netflix'), findsOneWidget);
  });

  testWidgets('creates a rule with the signed amount and the preferred account', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => (200, recurringIndex(const [])),
      'POST /v1/finance/recurring-rules': (_) => (201, {'data': recurringRuleJson()}),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, _iconButton('Nuevo recurrente'));
    expect(find.text('Nuevo recurrente'), findsWidgets);
    await tester.enterText(find.byType(TextField).at(0), '13,99');
    await tester.enterText(find.byType(TextField).at(1), 'Netflix');
    await tester.pump();
    await _tapAndSettle(tester, find.text('Guardar'));

    final body = api.requests.singleWhere((r) => r.method == 'POST').data as Map;
    expect(body['kind'], 'expense');
    expect(body['amount_cents'], -1399);
    expect(body['payee'], 'Netflix');
    expect(body['account_id'], 'acc-main');
    expect(body['category_id'], isNull);
    expect(body['frequency'], 'monthly');
    expect(body['interval'], 1);
    expect(body['end_date'], isNull);
    expect(body['mode'], 'auto');
    expect(body['remind_days_before'], 2);
    expect(body['is_subscription'], false);
    expect(find.text('Recurrente creado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('asks for the required fields before creating', (tester) async {
    final api = FakeApi({...financeBaseRoutes(), _rulesPath: (_) => (200, recurringIndex(const []))});
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, _iconButton('Nuevo recurrente'));
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Indica un importe mayor que cero.'), findsOneWidget);
    expect(find.text('Ponle un nombre, por ejemplo Netflix.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('edits a rule and sends the whole schedule', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => (200, recurringIndex(_rules)),
      'PATCH /v1/finance/recurring-rules/netflix': (_) => (200, {'data': recurringRuleJson()}),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, find.text('Netflix'));
    expect(find.text('Editar recurrente'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '15,99');
    await tester.pump();
    await _tapAndSettle(tester, find.text('Guardar'));

    final body = api.requests.singleWhere((r) => r.method == 'PATCH').data as Map;
    expect(body['amount_cents'], -1599);
    expect(body['payee'], 'Netflix');
    expect(body['category_id'], 'subs');
    expect(body['start_date'], '2026-01-27');
    expect(body['mode'], 'confirm');
    expect(body['is_subscription'], true);
    expect(find.text('Recurrente actualizado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('deletes a rule after confirming', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => (200, recurringIndex(_rules)),
      'DELETE /v1/finance/recurring-rules/netflix': (_) => (204, null),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, find.text('Netflix'));
    await tester.scrollUntilVisible(
      find.text('Eliminar'),
      200,
      scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first,
    );
    await _tapAndSettle(tester, find.text('Eliminar'));
    expect(find.text('¿Eliminar Netflix?'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Eliminar').last);

    expect(api.requests.where((r) => r.method == 'DELETE').single.path, '/v1/finance/recurring-rules/netflix');
    expect(find.text('Netflix eliminado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('cancels a subscription from the actions menu and undoes it', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => (200, recurringIndex(_rules)),
      'PATCH /v1/finance/recurring-rules/netflix': (_) => (200, {'data': recurringRuleJson()}),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, _iconButton('Acciones de Netflix'));
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Registrar el próximo cargo ya'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Cancelar suscripción'));

    expect(find.text('Netflix cancelada'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Deshacer'));

    final patches = [
      for (final request in api.requests)
        if (request.method == 'PATCH') request.data,
    ];
    expect(patches, [
      {'cancelled': true},
      {'cancelled': false},
    ]);
    expect(find.text('Netflix reactivada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('confirms a pending charge with a new price and updates the rule', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => (200, recurringIndex(_rules)),
      'POST /v1/finance/recurring-rules/spotify/confirm': (_) => (
        200,
        {
          'data': {
            'transaction': {'id': 'tx-sp', 'amount_cents': -1299, 'date': '2026-10-23'},
            'rule': recurringRuleJson(id: 'spotify', name: 'Spotify', amount: -1299),
            'price_changed': true,
            'previous_amount_cents': -1199,
          },
        },
      ),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, _iconButton('Confirmar cargo de Spotify'));
    expect(find.text('Confirmar Spotify'), findsOneWidget);
    expect(find.text('Mensual · día 27 · cargo del 23 oct · Cuenta corriente'), findsOneWidget);
    expect(find.text('Previsto: −11,99$nbsp€'), findsOneWidget);
    expect(find.textContaining('respecto a lo previsto'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '12,99');
    await tester.pump();
    expect(find.text('Sube 1,00$nbsp€ (8 %) respecto a lo previsto'), findsOneWidget);
    expect(find.text('Usar este importe en los próximos cargos'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Confirmar cargo'));

    final request = api.requests.singleWhere((r) => r.method == 'POST');
    expect(request.path, '/v1/finance/recurring-rules/spotify/confirm');
    expect(request.data, {'amount_cents': 1299, 'date': '2026-10-23', 'update_rule_amount': true});
    expect(find.text('Spotify confirmado: −12,99$nbsp€ · importe actualizado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('registers the next charge early without touching the rule amount', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      _rulesPath: (_) => (200, recurringIndex(_rules)),
      'POST /v1/finance/recurring-rules/netflix/confirm': (_) => (
        200,
        {
          'data': {
            'transaction': {'id': 'tx-new', 'amount_cents': -1399, 'date': '2026-10-27'},
            'rule': recurringRuleJson(nextOccurrence: '2026-11-27'),
            'price_changed': false,
            'previous_amount_cents': -1399,
          },
        },
      ),
    });
    await pumpFinance(tester, const RecurringScreen(), api);

    await _tapAndSettle(tester, _iconButton('Acciones de Netflix'));
    await _tapAndSettle(tester, find.text('Registrar el próximo cargo ya'));
    await _tapAndSettle(tester, find.text('Confirmar cargo'));

    final request = api.requests.singleWhere((r) => r.method == 'POST');
    expect(request.data, {'amount_cents': 1399, 'date': '2026-10-27', 'update_rule_amount': false});
    expect(find.text('Netflix confirmado: −13,99$nbsp€'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
