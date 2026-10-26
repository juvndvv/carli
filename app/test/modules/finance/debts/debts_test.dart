import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/format/dates.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/screens/debts/debt_sheet.dart';
import 'package:carli/modules/finance/screens/debts/debts_screen.dart';
import 'package:carli/ui/button.dart';
import 'package:carli/ui/progress.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';

const nbsp = ' ';

Json debtJson({
  String id = 'debt-car',
  String name = 'Préstamo coche',
  String direction = 'i_owe',
  String? contactId = 'cetelem',
  String? contactName = 'Cetelem',
  int principal = 1200000,
  int paid = 300000,
  int? installment = 25000,
  int? installments = 48,
  int installmentsPaid = 12,
  String? recurringRuleId = 'rule-1',
  String? nextPayment = '2026-11-05',
  String? due,
  String? notes,
  bool closed = false,
}) => {
  'id': id,
  'name': name,
  'direction': direction,
  'contact_id': contactId,
  'contact': contactId == null ? null : {'id': contactId, 'name': contactName},
  'principal_cents': principal,
  'paid_cents': paid,
  'pending_cents': principal - paid,
  'progress_bp': paid * 10000 ~/ principal,
  'start_date': '2025-11-05',
  'due_date': due,
  'installment_cents': installment,
  'installments_count': installments,
  'installments_paid': installmentsPaid,
  'recurring_rule_id': recurringRuleId,
  'next_payment_date': nextPayment,
  'notes': notes,
  'closed': closed,
  'closed_at': closed ? '2026-10-01T10:00:00+02:00' : null,
  'created_at': null,
  'updated_at': null,
};

Json debtsJson(List<Json> debts, {int owedToMe = 0, int iOwe = 900000}) => {
  'data': debts,
  'meta': {'owed_to_me_cents': owedToMe, 'i_owe_cents': iOwe},
};

Map<String, FakeRoute> debtRoutes({List<Json>? debts, List<Json>? payments, Json Function()? car}) => {
  ...financeBaseRoutes(),
  'GET /v1/finance/contacts': (_) => (
    200,
    {
      'data': [
        {'id': 'ana', 'name': 'Ana', 'archived': false, 'balance_cents': 1250},
        {'id': 'luis', 'name': 'Luis', 'archived': false, 'balance_cents': -4000},
        {'id': 'cetelem', 'name': 'Cetelem', 'archived': false, 'balance_cents': 0},
      ],
    },
  ),
  'GET /v1/finance/debts': (_) => (
    200,
    debtsJson(
      debts ??
          [
            car?.call() ?? debtJson(),
            debtJson(
              id: 'debt-luis',
              name: 'Dinero a Luis',
              direction: 'owed_to_me',
              contactId: 'luis',
              contactName: 'Luis',
              principal: 50000,
              paid: 10000,
              installment: null,
              installments: null,
              installmentsPaid: 0,
              recurringRuleId: null,
              nextPayment: null,
              due: '2026-12-01',
            ),
            debtJson(id: 'debt-old', name: 'Móvil', closed: true, principal: 60000, paid: 60000),
          ],
      owedToMe: 40000,
    ),
  ),
  'GET /v1/finance/debts/debt-car/payments': (_) => (
    200,
    {
      'data':
          payments ??
          [
            {
              ...transactionJson(
                id: 'pay-1',
                amount: -25000,
                payee: null,
                categoryId: null,
                date: DateTime(2026, 10, 5),
              ),
              'description': 'Cuota octubre',
            },
          ],
    },
  ),
};

Finder iconButton(String label) =>
    find.byWidgetPredicate((widget) => widget is CarliButton && widget.semanticLabel == label);

Json lastBody(FakeApi api, String method, [String? path]) =>
    api.requests.lastWhere((r) => r.method == method && (path == null || r.path == path)).data as Json;

Future<void> openDebt(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await settle(tester);
}

void main() {
  testWidgets('summarises debts, closed ones and shared balances', (tester) async {
    final api = FakeApi(debtRoutes());
    await pumpFinance(tester, const DebtsScreen(), api);

    expect(find.text('Te deben'), findsWidgets);
    expect(find.text('400,00$nbsp€'), findsOneWidget);
    expect(find.text('9.000,00$nbsp€'), findsOneWidget);
    expect(find.text('1 deuda abierta'), findsNWidgets(2));
    expect(find.text('Préstamo coche'), findsOneWidget);
    expect(find.text('Cetelem · 250,00$nbsp€ / mes · 12 de 48 cuotas'), findsOneWidget);
    expect(find.text('Luis · Sin plan de pagos'), findsOneWidget);
    expect(find.text('Próx. 5 nov'), findsOneWidget);
    expect(find.text('Vence 1 dic'), findsOneWidget);
    expect(find.text('Pendiente 9.000,00$nbsp€ de 12.000,00$nbsp€', findRichText: true), findsOneWidget);
    final bars = tester.widgetList<CarliProgress>(find.byType(CarliProgress)).toList();
    expect(bars, hasLength(2));
    expect(bars.every((bar) => bar.tone == ProgressTone.goal), isTrue);

    expect(find.text('Móvil'), findsNothing);
    await tester.scrollUntilVisible(find.text('Saldadas (1)'), 300);
    await tester.tap(find.text('Saldadas (1)'));
    await tester.pump();
    expect(find.text('Móvil'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Gastos compartidos'), 300);
    expect(find.text('Le debes 40,00$nbsp€'), findsOneWidget);
    expect(find.text('Te debe 12,50$nbsp€'), findsOneWidget);
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((data) => data == 'Ana' || data == 'Luis')
        .toList();
    expect(names, ['Luis', 'Ana']);
  });

  testWidgets('shows empty states when nothing is pending', (tester) async {
    final api = FakeApi({...financeBaseRoutes(), 'GET /v1/finance/debts': (_) => (200, debtsJson(const [], iOwe: 0))});
    await pumpFinance(tester, const DebtsScreen(), api);

    expect(find.text('Nada pendiente'), findsNWidgets(2));
    expect(find.text('Sin deudas pendientes'), findsOneWidget);
    expect(find.text('Nadie con saldo'), findsOneWidget);
  });

  testWidgets('shows the error state with retry', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/debts': (_) => (500, {'message': 'boom'}),
    });
    await pumpFinance(tester, const DebtsScreen(), api);

    expect(find.text('No se han podido cargar las deudas'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('creates a debt with a new contact and a monthly plan', (tester) async {
    final api = FakeApi({
      ...debtRoutes(debts: const []),
      'POST /v1/finance/contacts': (_) => (
        201,
        {
          'data': {'id': 'bank', 'name': 'Banco', 'archived': false, 'balance_cents': 0},
        },
      ),
      'POST /v1/finance/debts': (_) => (201, {'data': debtJson()}),
    });
    await pumpFinance(tester, const DebtsScreen(), api);

    await tester.tap(find.text('Nueva deuda'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva deuda'), findsWidgets);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Indica el importe total.'), findsOneWidget);
    expect(find.text('Ponle un nombre, por ejemplo Préstamo coche.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '12000');
    await tester.enterText(find.byType(TextField).at(1), 'Préstamo coche');
    await tester.tap(find.text('Sin contacto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo contacto…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'Banco');

    final planSwitch = find.descendant(
      of: find.ancestor(of: find.text('Pagar en cuotas mensuales'), matching: find.byType(Row)).first,
      matching: find.byType(CupertinoSwitch),
    );
    await tester.scrollUntilVisible(planSwitch, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(planSwitch);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Número de cuotas'), 200, scrollable: find.byType(Scrollable).last);
    await tester.enterText(
      find.descendant(
        of: find.ancestor(of: find.text('Cuota mensual'), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      ),
      '250',
    );
    await tester.enterText(
      find.descendant(
        of: find.ancestor(of: find.text('Número de cuotas'), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      ),
      '48',
    );
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(lastBody(api, 'POST', '/v1/finance/contacts'), {'name': 'Banco', 'notes': null});
    expect(lastBody(api, 'POST', '/v1/finance/debts'), {
      'name': 'Préstamo coche',
      'direction': 'i_owe',
      'principal_cents': 1200000,
      'start_date': isoDate(today()),
      'contact_id': 'bank',
      'due_date': null,
      'notes': null,
      'plan': {
        'account_id': 'acc-main',
        'installment_cents': 25000,
        'installments_count': 48,
        'first_payment_date': isoDate(addMonths(today(), 1)),
        'category_id': null,
      },
    });
    expect(find.text('Deuda creada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('registers a payment from the debt detail', (tester) async {
    var car = debtJson();
    final api = FakeApi({
      ...debtRoutes(car: () => car),
      'POST /v1/finance/debts/debt-car/payments': (_) {
        car = debtJson(paid: 325000, installmentsPaid: 13);
        return (
          201,
          {
            'data': transactionJson(id: 'pay-2', amount: -25000),
            'meta': {'debt': car},
          },
        );
      },
    });
    await pumpFinance(tester, const DebtsScreen(), api);
    await openDebt(tester, 'Préstamo coche');

    expect(find.text('Cetelem · 250,00$nbsp€ / mes · 12 de 48 cuotas'), findsWidgets);
    expect(find.text('25 %'), findsOneWidget);
    expect(find.text('Registrar pago'), findsWidgets);
    expect(find.text('Cuota octubre'), findsOneWidget);
    expect(find.text('−250,00$nbsp€'), findsOneWidget);

    await tester.tap(find.widgetWithText(CarliButton, 'Registrar pago'));
    await settle(tester);

    expect(lastBody(api, 'POST'), {'account_id': 'acc-main', 'amount_cents': 25000, 'date': isoDate(today())});
    expect(find.text('Registrar pago: −250,00$nbsp€'), findsOneWidget);
    expect(find.text('Cetelem · 250,00$nbsp€ / mes · 13 de 48 cuotas'), findsWidgets);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('fills the pending amount and announces a settled debt', (tester) async {
    var car = debtJson();
    final api = FakeApi({
      ...debtRoutes(car: () => car),
      'POST /v1/finance/debts/debt-car/payments': (_) {
        car = debtJson(paid: 1200000, closed: true);
        return (
          201,
          {
            'data': transactionJson(id: 'pay-2', amount: -900000),
            'meta': {'debt': car},
          },
        );
      },
    });
    await pumpFinance(tester, const DebtsScreen(), api);
    await openDebt(tester, 'Préstamo coche');

    await tester.tap(find.text('Todo lo pendiente'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CarliButton, 'Registrar pago'));
    await settle(tester);

    expect(lastBody(api, 'POST')['amount_cents'], 900000);
    expect(find.text('Préstamo coche saldada'), findsOneWidget);
    expect(find.text('Saldada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('uses collection copy for debts owed to me', (tester) async {
    final api = FakeApi({
      ...debtRoutes(),
      'GET /v1/finance/debts/debt-luis/payments': (_) => (200, {'data': <Json>[]}),
    });
    await pumpFinance(tester, const DebtsScreen(), api);
    await openDebt(tester, 'Dinero a Luis');

    expect(find.text('Registrar cobro'), findsWidgets);
    expect(find.text('Cobros'), findsOneWidget);
    expect(find.text('Aún no hay cobros registrados.'), findsOneWidget);
  });

  testWidgets('deletes a payment and restores it on undo', (tester) async {
    final api = FakeApi({
      ...debtRoutes(),
      'DELETE /v1/finance/transactions/pay-1': (_) => (
        200,
        {
          'data': null,
          'meta': {'periods_changed': false},
        },
      ),
      'POST /v1/finance/transactions/pay-1/restore': (_) => (
        200,
        {
          'data': transactionJson(id: 'pay-1', amount: -25000),
          'meta': {'periods_changed': false},
        },
      ),
    });
    await pumpFinance(tester, const DebtsScreen(), api);
    await openDebt(tester, 'Préstamo coche');

    await tester.scrollUntilVisible(iconButton('Borrar pago del 5 oct'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(iconButton('Borrar pago del 5 oct'));
    await settle(tester);
    expect(find.text('Pago borrado'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);

    expect(api.requests.where((r) => r.method == 'DELETE' && r.path == '/v1/finance/transactions/pay-1'), hasLength(1));
    expect(api.requests.where((r) => r.path == '/v1/finance/transactions/pay-1/restore'), hasLength(1));
  });

  testWidgets('marks a debt as settled and reopens it on undo', (tester) async {
    final patches = <Json>[];
    var car = debtJson();
    final api = FakeApi({
      ...debtRoutes(car: () => car),
      'PATCH /v1/finance/debts/debt-car': (options) {
        final body = options.data as Json;
        patches.add(body);
        car = debtJson(closed: body['closed'] == true);
        return (200, {'data': car});
      },
    });
    await pumpFinance(tester, const DebtsScreen(), api);
    await openDebt(tester, 'Préstamo coche');

    await tester.scrollUntilVisible(find.text('Marcar como saldada'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Marcar como saldada'));
    await settle(tester);
    expect(find.text('Préstamo coche marcada como saldada'), findsOneWidget);
    expect(find.text('Reabrir'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(patches, [
      {'closed': true},
      {'closed': false},
    ]);
    expect(find.text('Marcar como saldada'), findsOneWidget);
  });

  testWidgets('edits a debt without resending a plan when it already has one', (tester) async {
    var car = debtJson();
    final api = FakeApi({
      ...debtRoutes(car: () => car),
      'PATCH /v1/finance/debts/debt-car': (_) {
        car = debtJson(name: 'Préstamo coche nuevo');
        return (200, {'data': car});
      },
    });
    await pumpFinance(tester, const DebtsScreen(), api);
    await openDebt(tester, 'Préstamo coche');

    await tester.tap(iconButton('Editar deuda'));
    await tester.pumpAndSettle();
    expect(find.text('Editar deuda'), findsOneWidget);
    expect(find.text('Pagar en cuotas mensuales'), findsNothing);
    await tester.enterText(
      find.descendant(of: find.byType(DebtSheet), matching: find.byType(TextField)).at(1),
      'Préstamo coche nuevo',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(lastBody(api, 'PATCH'), {
      'name': 'Préstamo coche nuevo',
      'direction': 'i_owe',
      'principal_cents': 1200000,
      'start_date': '2025-11-05',
      'contact_id': 'cetelem',
      'due_date': null,
      'notes': null,
    });
    expect(find.text('Deuda actualizada'), findsOneWidget);
    expect(find.text('Préstamo coche nuevo'), findsWidgets);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('deletes a debt after confirming', (tester) async {
    final api = FakeApi({...debtRoutes(), 'DELETE /v1/finance/debts/debt-car': (_) => (204, null)});
    await pumpFinance(tester, const DebtsScreen(), api);
    await openDebt(tester, 'Préstamo coche');

    await tester.scrollUntilVisible(
      find.widgetWithText(CarliButton, 'Eliminar'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(CarliButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar Préstamo coche?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Eliminar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(api.requests.where((r) => r.method == 'DELETE' && r.path == '/v1/finance/debts/debt-car'), hasLength(1));
    expect(find.text('Préstamo coche eliminada'), findsOneWidget);
    expect(find.text('Marcar como saldada'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}
