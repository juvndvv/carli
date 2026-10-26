import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/json.dart';

import '../../core/pending/pending_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';
import 'pending_app.dart';

Json _suggestionJson() => pendingItemJson(
  type: 'transfer_suggestion',
  id: 'tx-out',
  title: '¿Es una transferencia entre BBVA y Revolut?',
  subtitle: 'BBVA → Revolut',
  amount: 12000,
  route: '/finanzas/movimientos?periodo=todos',
  meta: {
    'outgoing_transaction_id': 'tx-out',
    'incoming_transaction_id': 'tx-in',
    'signals': <String>[],
    'unique': true,
  },
);

Map<String, FakeRoute> _routes(List<Json> Function() items) => {
  'GET /v1/pending': (_) => (200, pendingPageJson(items())),
  'GET /v1/pending/summary': (_) {
    final count = items().length;
    return (
      200,
      {
        'data': {
          'total': count,
          'by_module': [
            if (count > 0)
              {'module': 'finance', 'module_name': 'Finanzas', 'type': 'transfer_suggestion', 'count': count},
          ],
        },
      },
    );
  },
};

void main() {
  testWidgets('shows a transfer suggestion with a neutral amount and both answers', (tester) async {
    await pumpPendingRouter(
      tester,
      FakeApi({
        ...financeBaseRoutes(),
        ..._routes(() => [_suggestionJson()]),
      }),
    );

    expect(find.text('Posibles transferencias'), findsOneWidget);
    expect(find.text('¿Es una transferencia entre BBVA y Revolut?'), findsOneWidget);
    expect(find.text('120,00 €'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(find.text('No es transferencia'), findsOneWidget);
  });

  testWidgets('confirms a suggestion and offers to undo it', (tester) async {
    var items = [_suggestionJson()];
    final api = FakeApi({
      ...financeBaseRoutes(),
      ..._routes(() => items),
      'POST /v1/finance/transfers/suggestions/confirm': (_) {
        items = [];
        return (201, {'data': <String, Object>{}});
      },
      'POST /v1/finance/transactions/tx-out/undo-transfer': (_) => (200, {'data': <Json>[]}),
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('Confirmar'));

    final confirm = api.requests.singleWhere((request) => request.path.endsWith('/suggestions/confirm'));
    expect(confirm.data, {'outgoing_transaction_id': 'tx-out', 'incoming_transaction_id': 'tx-in'});
    expect(find.text('¿Es una transferencia entre BBVA y Revolut?'), findsNothing);
    expect(find.text('Guardada como transferencia'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(api.requests.where((request) => request.path.endsWith('/undo-transfer')), hasLength(1));
    await drainToasts(tester);
  });

  testWidgets('remembers that a suggestion is not a transfer', (tester) async {
    var items = [_suggestionJson()];
    final api = FakeApi({
      ...financeBaseRoutes(),
      ..._routes(() => items),
      'POST /v1/finance/transfers/suggestions/dismiss': (_) {
        items = [];
        return (
          200,
          {
            'data': {'dismissed': true},
          },
        );
      },
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('No es transferencia'));

    expect(api.requests.where((request) => request.path.endsWith('/suggestions/dismiss')), hasLength(1));
    expect(find.text('¿Es una transferencia entre BBVA y Revolut?'), findsNothing);
    expect(find.text('Entendido: no es una transferencia'), findsOneWidget);
    await drainToasts(tester);
  });

  testWidgets('keeps the suggestion when the answer fails', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      ..._routes(() => [_suggestionJson()]),
      'POST /v1/finance/transfers/suggestions/confirm': (_) => (
        422,
        {
          'message': 'Los importes de los dos movimientos no coinciden.',
          'errors': {
            'incoming_transaction_id': ['Los importes de los dos movimientos no coinciden.'],
          },
        },
      ),
    });
    await pumpPendingRouter(tester, api);

    await tapAndSettle(tester, find.text('Confirmar'));

    expect(find.text('¿Es una transferencia entre BBVA y Revolut?'), findsOneWidget);
    expect(find.textContaining('no coinciden'), findsOneWidget);
    await drainToasts(tester);
  });
}
