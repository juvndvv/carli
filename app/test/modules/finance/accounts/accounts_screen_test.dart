import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/format/dates.dart';
import 'package:carli/core/theme/theme.dart';
import 'package:carli/core/theme/tokens.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/screens/accounts/account_detail_screen.dart';
import 'package:carli/modules/finance/screens/accounts/accounts_screen.dart';
import 'package:carli/ui/button.dart';
import 'package:carli/ui/skeleton.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';
import '../../../support/test_app.dart';
import 'accounts_fixtures.dart';

const nbsp = '\u00a0';

FakeApi accountsApi(List<Json> accounts, {Map<String, FakeRoute> extra = const {}, int netWorth = 342865}) => FakeApi({
  ...financeBaseRoutes(),
  'GET /v1/finance/accounts': (_) => (200, accountsBody(accounts, netWorth: netWorth)),
  ...extra,
});

Finder optionsOf(String name) =>
    find.byWidgetPredicate((widget) => widget is CarliButton && widget.semanticLabel == 'Opciones de $name');

Future<void> openMenu(WidgetTester tester, String name) async {
  await tester.tap(optionsOf(name));
  await tester.pumpAndSettle();
}

Map<dynamic, dynamic> bodyOf(FakeApi api, String method) =>
    api.requests.lastWhere((request) => request.method == method).data as Map;

void main() {
  testWidgets('shows skeletons while the accounts load', (tester) async {
    final api = accountsApi([fullAccountJson()]);
    final container = testContainer(api, storage: {'auth_token': 'stored'});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: carliTheme(Brightness.light),
          locale: const Locale('es', 'ES'),
          supportedLocales: const [Locale('es', 'ES')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AccountsScreen(),
        ),
      ),
    );

    expect(find.byType(CarliSkeleton), findsWidgets);
    await settle(tester);
    expect(find.byType(CarliSkeleton), findsNothing);
    expect(find.text('Patrimonio neto'), findsOneWidget);
  });

  testWidgets('lists accounts with net worth, pending, credit and bank lines', (tester) async {
    final api = accountsApi([
      fullAccountJson(pending: -2500, bank: bankLinkJson()),
      fullAccountJson(
        id: 'acc-card',
        name: 'Visa',
        type: 'credit_card',
        balance: -45000,
        creditLimit: 300000,
        statementDay: 5,
        paymentDay: 10,
      ),
      fullAccountJson(id: 'acc-cash', name: 'Cartera', type: 'cash', balance: 3000, includeInNetWorth: false),
      fullAccountJson(id: 'acc-old', name: 'Antigua', archived: true),
    ]);
    await pumpFinance(tester, const AccountsScreen(), api);

    expect(api.requests.first.queryParameters['include_archived'], '1');
    expect(find.text('3.428,65$nbsp€'), findsWidgets);
    expect(find.text('3 cuentas · las tarjetas de crédito restan'), findsOneWidget);
    expect(find.text('Pendiente −25,00$nbsp€ · confirmado 3.453,65$nbsp€'), findsOneWidget);
    expect(find.textContaining('diferencia'), findsOneWidget);
    expect(find.text('Dispuesto 450,00$nbsp€'), findsOneWidget);
    expect(find.text('Disponible 2.550,00$nbsp€'), findsOneWidget);
    expect(find.text('Corte día 5 · se carga el día 10'), findsOneWidget);
    expect(find.text('Efectivo · fuera del patrimonio'), findsOneWidget);
    final card = tester.widget<Text>(find.text('−450,00$nbsp€'));
    expect(card.style?.color, CarliColors.light.text);
    expect(find.text('Antigua'), findsNothing);

    await tester.ensureVisible(find.text('1 cuenta archivada · mostrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 cuenta archivada · mostrar'));
    await tester.pump();
    expect(find.text('Antigua'), findsOneWidget);
    expect(find.text('Archivada'), findsOneWidget);
  });

  testWidgets('invites to create the first account', (tester) async {
    await pumpFinance(tester, const AccountsScreen(), accountsApi(const []));

    expect(find.text('Aún no tienes cuentas'), findsOneWidget);
    expect(find.text('Añadir cuenta'), findsOneWidget);
  });

  testWidgets('retries after a failed load', (tester) async {
    var calls = 0;
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/accounts': (_) =>
          ++calls == 1 ? (500, {'message': 'Server error'}) : (200, accountsBody([fullAccountJson()])),
    });
    await pumpFinance(tester, const AccountsScreen(), api);

    expect(find.text('No se han podido cargar las cuentas'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await settle(tester);
    expect(find.text('BBVA'), findsOneWidget);
  });

  testWidgets('creates an account with the Angular defaults', (tester) async {
    final api = accountsApi(
      const [],
      extra: {
        'POST /v1/finance/accounts': (_) => (201, {'data': fullAccountJson(name: 'Nómina')}),
      },
    );
    await pumpFinance(tester, const AccountsScreen(), api);

    await tester.tap(find.text('Añadir cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cuenta'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Ponle un nombre.'), findsOneWidget);
    expect(api.requests.where((request) => request.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextField).first, ' Nómina ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(bodyOf(api, 'POST'), {
      'name': 'Nómina',
      'type': 'checking',
      'initial_balance_cents': 0,
      'initial_balance_date': isoDate(today()),
      'credit_limit_cents': null,
      'statement_day': null,
      'payment_day': null,
      'icon': 'landmark',
      'color': null,
      'include_in_net_worth': true,
    });
    expect(find.text('Cuenta creada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('edits a credit card with its limit and days', (tester) async {
    final card = fullAccountJson(
      id: 'acc-card',
      name: 'Visa',
      type: 'credit_card',
      balance: -45000,
      creditLimit: 300000,
      statementDay: 5,
      paymentDay: 10,
      icon: 'credit-card',
      color: 'c2',
    );
    final api = accountsApi(
      [card],
      extra: {
        'PATCH /v1/finance/accounts/acc-card': (_) => (200, {'data': card}),
      },
    );
    await pumpFinance(tester, const AccountsScreen(), api);

    await openMenu(tester, 'Visa');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar cuenta'), findsOneWidget);
    expect(find.text('En negativo si ya debías algo.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '5'), '7');
    await tester.ensureVisible(find.bySemanticsLabel('Color 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Color 4'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    final body = bodyOf(api, 'PATCH');
    expect(body['type'], 'credit_card');
    expect(body['credit_limit_cents'], 300000);
    expect(body['statement_day'], 7);
    expect(body['payment_day'], 10);
    expect(body['color'], 'c4');
    expect(body['icon'], 'credit-card');
    expect(find.text('Cuenta actualizada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('archives with undo and toggles net worth', (tester) async {
    final api = accountsApi(
      [fullAccountJson()],
      extra: {
        'PATCH /v1/finance/accounts/acc-main': (_) => (200, {'data': fullAccountJson()}),
      },
    );
    await pumpFinance(tester, const AccountsScreen(), api);

    await openMenu(tester, 'BBVA');
    await tester.tap(find.text('Archivar'));
    await settle(tester);
    expect(bodyOf(api, 'PATCH'), {'archived': true});
    expect(find.text('BBVA archivada'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(bodyOf(api, 'PATCH'), {'archived': false});

    await openMenu(tester, 'BBVA');
    await tester.tap(find.text('Excluir del patrimonio'));
    await settle(tester);
    expect(bodyOf(api, 'PATCH'), {'include_in_net_worth': false});
    expect(find.text('BBVA ya no suma al patrimonio'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('deletes after confirming and explains when it has movements', (tester) async {
    var deletes = 0;
    final api = accountsApi(
      [fullAccountJson()],
      extra: {
        'DELETE /v1/finance/accounts/acc-main': (_) => ++deletes == 1
            ? (
                422,
                {
                  'message': 'invalid',
                  'errors': {
                    'account': ['La cuenta tiene movimientos. Archívala en lugar de borrarla.'],
                  },
                },
              )
            : (204, null),
      },
    );
    await pumpFinance(tester, const AccountsScreen(), api);

    await openMenu(tester, 'BBVA');
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar BBVA?'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('La cuenta tiene movimientos. Archívala en lugar de borrarla.'), findsOneWidget);

    await openMenu(tester, 'BBVA');
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(deletes, 2);
    expect(find.text('Cuenta eliminada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('reconciles against the linked bank balance', (tester) async {
    final api = accountsApi(
      [fullAccountJson(bank: bankLinkJson())],
      extra: {
        'POST /v1/finance/accounts/acc-main/reconcile': (_) => (
          201,
          {
            'data': {
              'account': fullAccountJson(balance: 343365),
              'adjustment': transactionJson(id: 'adj', kind: 'adjustment', amount: 500, payee: null),
              'difference_cents': 500,
              'balance_cents': 343365,
            },
          },
        ),
      },
    );
    await pumpFinance(tester, const AccountsScreen(), api);

    await tester.tap(find.text('Conciliar'));
    await tester.pumpAndSettle();

    expect(find.text('Conciliar cuenta'), findsOneWidget);
    expect(find.textContaining('Precargado con el saldo que informa BBVA'), findsOneWidget);
    expect(find.text('Se creará un movimiento de ajuste de +5,00$nbsp€.', findRichText: true), findsOneWidget);

    await tester.tap(find.widgetWithText(CarliButton, 'Conciliar').last);
    await tester.pumpAndSettle();
    await settle(tester);

    expect(bodyOf(api, 'POST'), {'actual_balance_cents': 343365, 'date': isoDate(today())});
    expect(find.text('Cuenta conciliada · ajuste de +5,00$nbsp€'), findsOneWidget);
    expect(find.text('Conciliar cuenta'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('says the balance already matched', (tester) async {
    final api = accountsApi(
      [fullAccountJson()],
      extra: {
        'POST /v1/finance/accounts/acc-main/reconcile': (_) => (
          200,
          {
            'data': {'account': fullAccountJson(), 'adjustment': null, 'difference_cents': 0, 'balance_cents': 342865},
          },
        ),
      },
    );
    await pumpFinance(tester, const AccountsScreen(), api);

    await tester.tap(find.text('Conciliar'));
    await tester.pumpAndSettle();
    expect(find.text('El saldo cuadra. No hace falta ningún ajuste.'), findsOneWidget);
    await tester.tap(find.widgetWithText(CarliButton, 'Conciliar').last);
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('Cuenta conciliada · el saldo ya cuadraba'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('shows the account detail with stats, bank and recent movements', (tester) async {
    final api = accountsApi(
      [fullAccountJson(pending: -2500, bank: bankLinkJson())],
      extra: {
        'GET /v1/finance/transactions': (_) => (200, transactionPage([transactionJson()])),
      },
    );
    await pumpFinance(tester, const AccountDetailScreen(accountId: 'acc-main'), api);

    expect(find.text('BBVA'), findsWidgets);
    expect(find.text('Saldo actual'), findsOneWidget);
    expect(find.text('Corriente'), findsOneWidget);
    expect(find.text('Sin contar pendientes'), findsOneWidget);
    expect(find.text('−25,00$nbsp€'), findsOneWidget);
    expect(find.text('Suma al patrimonio'), findsOneWidget);
    expect(find.text('Banco'), findsOneWidget);
    expect(find.widgetWithText(CarliButton, 'Conciliar'), findsOneWidget);

    final query = api.requests.firstWhere((request) => request.path == '/v1/finance/transactions').queryParameters;
    expect(query['account_id[]'], ['acc-main']);
    expect(query['from'], isoDate(DateTime(today().year, today().month, today().day - 90)));
    expect(query['per_page'], '200');

    await tester.scrollUntilVisible(find.text('Mercadona'), 300);
    expect(find.text('Movimientos recientes'), findsOneWidget);
    expect(find.text('Mercadona'), findsOneWidget);
  });

  testWidgets('shows a credit card detail with its limit', (tester) async {
    final api = accountsApi(
      [
        fullAccountJson(
          id: 'acc-card',
          name: 'Visa',
          type: 'credit_card',
          balance: -45000,
          creditLimit: 300000,
          statementDay: 5,
        ),
      ],
      extra: {'GET /v1/finance/transactions': (_) => (200, transactionPage(const []))},
    );
    await pumpFinance(tester, const AccountDetailScreen(accountId: 'acc-card'), api);

    expect(find.text('Crédito'), findsOneWidget);
    expect(find.text('Límite 3.000,00$nbsp€ · Corte día 5'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sin movimientos'), 300);
    expect(find.text('Añadir movimiento'), findsOneWidget);
  });

  testWidgets('says when the account no longer exists', (tester) async {
    final api = accountsApi(const []);
    await pumpFinance(tester, const AccountDetailScreen(accountId: 'gone'), api);

    expect(api.requests.any((request) => request.path == '/v1/finance/accounts/gone'), isTrue);
    expect(find.text('No encontramos esta cuenta'), findsOneWidget);
    expect(find.text('Volver a cuentas'), findsOneWidget);
  });
}
