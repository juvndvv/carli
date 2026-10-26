import 'package:flutter/cupertino.dart';
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

  Future<void> openMore(WidgetTester tester) async {
    final more = find.textContaining('Más opciones');
    await tester.scrollUntilVisible(more, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(more);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);
  }

  testWidgets('shares an expense equally and adds tags', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'POST /v1/finance/transactions': (_) => (201, {'data': transactionJson(id: 'new'), 'meta': {}}),
    });
    await pumpFinance(tester, const _Opener(), api);
    await openSheet(tester);

    await tester.enterText(find.byType(TextField).first, '30');
    await tester.tap(find.text('Comida'));
    await openMore(tester);

    final tagField = find.widgetWithText(TextField, 'Añadir etiqueta');
    await tester.scrollUntilVisible(tagField, 200, scrollable: find.byType(Scrollable).last);
    await tester.enterText(tagField, 'Viaje,');
    await tester.pump();
    expect(find.text('#viaje'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Gasto compartido'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text('Gasto compartido'), matching: find.byType(Row)).first,
        matching: find.byType(CupertinoSwitch),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Ana'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Ana'));
    await tester.pump();

    expect(find.text('Ana te debe 15,00\u00A0€ · tu parte 15,00\u00A0€'), findsOneWidget);
    await save(tester);

    final body = api.requests.singleWhere((r) => r.method == 'POST').data as Map;
    expect(body['tags'], ['viaje']);
    expect(body['shares'], {
      'mode': 'equal',
      'include_self': true,
      'items': [
        {'contact_id': 'ana'},
      ],
    });
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('keeps splits untouched unless they are edited, and removes them when turned off', (tester) async {
    final split = Transaction.fromJson({
      ...transactionJson(amount: -1000, categoryId: null),
      'splits': [
        {'id': 's1', 'category_id': 'cat-food', 'amount_cents': -600, 'category': null},
        {'id': 's2', 'category_id': 'cat-home', 'amount_cents': -400, 'category': null},
      ],
    });
    final api = FakeApi({
      ...financeBaseRoutes(),
      'PATCH /v1/finance/transactions/tx-1': (_) => (200, {'data': transactionJson(), 'meta': {}}),
    });
    await pumpFinance(tester, _Opener(transaction: split), api);
    await openSheet(tester);

    await tester.scrollUntilVisible(find.text('Reparto completo'), 200, scrollable: find.byType(Scrollable).last);
    await save(tester);
    var body = api.requests.lastWhere((r) => r.method == 'PATCH').data as Map;
    expect(body.containsKey('splits'), isFalse);
    expect(body['category_id'], isNull);
    await tester.pump(const Duration(seconds: 6));

    await openSheet(tester);
    final splitRow = find.ancestor(of: find.text('Dividir en varias categorías'), matching: find.byType(Row)).first;
    await tester.scrollUntilVisible(
      find.text('Dividir en varias categorías'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.descendant(of: splitRow, matching: find.byType(CupertinoSwitch)));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Comida'), -200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Comida'));
    await save(tester);

    body = api.requests.lastWhere((r) => r.method == 'PATCH').data as Map;
    expect(body['splits'], isNull);
    expect(body.containsKey('splits'), isTrue);
    expect(body['category_id'], 'cat-food');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('blocks saving when the split does not add up', (tester) async {
    final split = Transaction.fromJson({
      ...transactionJson(amount: -1500, categoryId: null),
      'splits': [
        {'id': 's1', 'category_id': 'cat-food', 'amount_cents': -600, 'category': null},
      ],
    });
    final api = FakeApi(financeBaseRoutes());
    await pumpFinance(tester, _Opener(transaction: split), api);
    await openSheet(tester);

    await tester.scrollUntilVisible(
      find.text('Quedan 9,00\u00A0€ por asignar'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('El reparto entre categorías debe sumar el importe total.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });
}
