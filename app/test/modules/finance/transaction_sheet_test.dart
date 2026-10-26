import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/screens/transaction_sheet.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';

class _Opener extends StatelessWidget {
  const _Opener({this.transaction});

  final Transaction? transaction;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showTransactionSheet(context, transaction: transaction),
        child: const Text('Abrir'),
      ),
    ),
  );
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  await settle(tester);
}

void main() {
  testWidgets('creates an expense with the signed amount, preferred account and category', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'POST /v1/finance/transactions': (options) => (
        201,
        {
          'data': transactionJson(id: 'new'),
          'meta': {'periods_changed': false},
        },
      ),
    });
    await pumpFinance(tester, const _Opener(), api);
    await openSheet(tester);

    expect(find.text('Nuevo movimiento'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '42,5');
    await tester.tap(find.text('Comida'));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    final body = api.requests.singleWhere((r) => r.method == 'POST').data as Map;
    expect(body['kind'], 'expense');
    expect(body['amount_cents'], -4250);
    expect(body['account_id'], 'acc-main');
    expect(body['category_id'], 'cat-food');
    expect(body.containsKey('splits'), isFalse);
    expect(find.text('Movimiento guardado'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('asks for an amount before saving', (tester) async {
    final api = FakeApi(financeBaseRoutes());
    await pumpFinance(tester, const _Opener(), api);
    await openSheet(tester);

    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Introduce un importe mayor que 0.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('edits a movement and keeps its tags', (tester) async {
    final original = Transaction.fromJson({
      ...transactionJson(),
      'tags': ['viaje'],
    });
    final api = FakeApi({
      ...financeBaseRoutes(),
      'PATCH /v1/finance/transactions/tx-1': (_) => (
        200,
        {
          'data': transactionJson(),
          'meta': {'periods_changed': true},
        },
      ),
    });
    await pumpFinance(tester, _Opener(transaction: original), api);
    await openSheet(tester);

    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(find.text('Transferencia'), findsNothing);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    final body = api.requests.singleWhere((r) => r.method == 'PATCH').data as Map;
    expect(body['amount_cents'], -4250);
    expect(body['tags'], ['viaje']);
    expect(find.text('Cambios guardados · periodos recalculados'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('deletes from the sheet and offers Deshacer', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'DELETE /v1/finance/transactions/tx-1': (_) => (
        200,
        {
          'meta': {'periods_changed': false},
        },
      ),
      'POST /v1/finance/transactions/tx-1/restore': (_) => (200, {'data': transactionJson(), 'meta': {}}),
    });
    await pumpFinance(tester, _Opener(transaction: Transaction.fromJson(transactionJson())), api);
    await openSheet(tester);

    await tester.scrollUntilVisible(find.text('Eliminar movimiento'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Eliminar movimiento'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('Movimiento eliminado'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);

    expect(api.requests.any((r) => r.path.endsWith('/restore')), isTrue);
  });

  testWidgets('locks bank fields and explains why', (tester) async {
    final imported = Transaction.fromJson({
      ...transactionJson(source: 'bank'),
      'bank': {'aspsp_name': 'BBVA'},
    });
    await pumpFinance(tester, _Opener(transaction: imported), FakeApi(financeBaseRoutes()));
    await openSheet(tester);

    expect(find.textContaining('Importado de BBVA'), findsOneWidget);
  });
}
