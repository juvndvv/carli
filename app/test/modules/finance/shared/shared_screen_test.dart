import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/core/format/dates.dart';
import 'package:carli/core/router/router.dart';
import 'package:carli/core/theme/theme.dart';
import 'package:carli/core/theme/tokens.dart';
import 'package:carli/modules/finance/data/contacts.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/screens/shared/contact_detail_screen.dart';
import 'package:carli/modules/finance/screens/shared/shared_screen.dart';
import 'package:carli/ui/toast.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';
import '../../../support/test_app.dart';

const nbsp = '\u00a0';

Json contactJson({
  String id = 'ana',
  String name = 'Ana',
  String? notes,
  bool archived = false,
  int balance = 4000,
  int sharesPending = 4000,
  int owedToMe = 0,
  int iOwe = 0,
}) => {
  'id': id,
  'name': name,
  'notes': notes,
  'archived': archived,
  'balance_cents': balance,
  'shares_pending_cents': sharesPending,
  'owed_to_me_cents': owedToMe,
  'i_owe_cents': iOwe,
};

Json shareJson({String id = 's-1', bool settled = false, int amount = 4000, String? payee = 'Cena', DateTime? date}) =>
    {
      'id': id,
      'transaction_id': 'tx-$id',
      'date': isoDate(date ?? today()),
      'payee': payee,
      'description': null,
      'transaction_amount_cents': -8000,
      'amount_cents': amount,
      'settled': settled,
      'settled_at': settled ? '2026-10-01T10:00:00+02:00' : null,
      'settlement_transaction_id': settled ? 'tx-settle' : null,
    };

Json debtJson({String direction = 'owed_to_me', bool closed = false}) => {
  'id': 'd-1',
  'name': 'Préstamo coche',
  'direction': direction,
  'contact': {'id': 'ana', 'name': 'Ana'},
  'principal_cents': 30000,
  'pending_cents': 30000,
  'due_date': '2026-11-03',
  'closed': closed,
};

Json detailJson({Json? contact, List<Json> shares = const [], List<Json> debts = const []}) => {
  ...contact ?? contactJson(),
  'shares': shares,
  'debts': debts,
};

Map<String, FakeRoute> contactsRoutes({List<Json>? contacts, Json? meta, Json? detail}) => {
  ...financeBaseRoutes(),
  'GET /v1/finance/contacts': (_) => (
    200,
    {
      'data':
          contacts ??
          [contactJson(), contactJson(id: 'carlos', name: 'Carlos', balance: -2350, sharesPending: 0, iOwe: 2350)],
      'meta': meta ?? {'owed_to_me_cents': 4000, 'i_owe_cents': 2350},
    },
  ),
  'GET /v1/finance/contacts/ana': (_) => (200, {'data': detail ?? detailJson()}),
};

Json bodyOf(FakeApi api, String method, String path) =>
    api.requests.lastWhere((request) => request.method == method && request.path == path).data as Json;

void main() {
  group('contact labels', () {
    test('summarise what is pending with each contact', () {
      FinanceContact contact(Json overrides) => FinanceContact.fromJson({...contactJson(), ...overrides});
      expect(contactSubtitle(contact({})), '40,00$nbsp€ en gastos sin liquidar');
      expect(
        contactSubtitle(contact({'shares_pending_cents': 0, 'owed_to_me_cents': 30000})),
        'Te debe 300,00$nbsp€ en préstamos',
      );
      expect(contactSubtitle(contact({'shares_pending_cents': 0})), 'Sin nada pendiente');
      expect(contactBalanceLabel(4000), 'Te debe 40,00$nbsp€');
      expect(contactBalanceLabel(-2350), 'Le debes 23,50$nbsp€');
      expect(contactBalanceLabel(0), 'En paz');
      expect(peopleLabel(0), 'Nadie');
      expect(peopleLabel(2), '2 personas');
    });
  });

  testWidgets('shows balances from my point of view and offers settling only with pending shares', (tester) async {
    await pumpFinance(tester, const SharedScreen(), FakeApi(contactsRoutes()));

    expect(find.text('Te deben'), findsOneWidget);
    expect(find.text('40,00$nbsp€'), findsOneWidget);
    expect(find.text('1 persona'), findsNWidgets(2));
    expect(find.text('23,50$nbsp€'), findsOneWidget);
    final owed = tester.widget<Text>(find.text('Te debe 40,00$nbsp€'));
    expect(owed.style?.color, CarliColors.light.positive);
    expect(find.text('Le debes 23,50$nbsp€'), findsOneWidget);
    expect(find.text('Le debes 23,50$nbsp€ en préstamos'), findsOneWidget);
    expect(find.text('Liquidar'), findsOneWidget);
  });

  testWidgets('invites to add the first contact and creates it', (tester) async {
    final api = FakeApi({
      ...contactsRoutes(contacts: const [], meta: {'owed_to_me_cents': 0, 'i_owe_cents': 0}),
      'POST /v1/finance/contacts': (_) => (
        201,
        {
          'data': detailJson(
            contact: contactJson(id: 'luis', name: 'Luis', balance: 0, sharesPending: 0),
          ),
        },
      ),
    });
    await pumpFinance(tester, const SharedScreen(), api);

    expect(find.text('Aún no compartes gastos'), findsOneWidget);
    expect(find.text('Nadie'), findsNWidgets(2));
    await tester.tap(find.text('Nuevo contacto').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir contacto'));
    await tester.pump();
    expect(find.text('Escribe un nombre.'), findsOneWidget);
    expect(api.requests.where((request) => request.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextField).first, '  Luis ');
    await tester.tap(find.text('Añadir contacto'));
    await tester.pumpAndSettle();

    expect(bodyOf(api, 'POST', '/v1/finance/contacts'), {'name': 'Luis', 'notes': null});
    expect(find.text('Luis añadido'), findsOneWidget);
    expect(
      api.requests.where((request) => request.method == 'GET' && request.path == '/v1/finance/contacts').length,
      2,
    );
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('settles with the preferred account and undoes every settlement movement', (tester) async {
    final api = FakeApi({
      ...contactsRoutes(),
      'POST /v1/finance/contacts/ana/settle': (_) => (
        201,
        {
          'data': {
            'transaction': {'id': 'tx-settle'},
            'transactions': [
              {'id': 'tx-settle'},
              {'id': 'tx-settle-2'},
            ],
            'net_cents': 4000,
            'contact': contactJson(balance: 0, sharesPending: 0),
          },
        },
      ),
      'DELETE /v1/finance/transactions/tx-settle': (_) => (200, {'meta': <String, Object>{}}),
      'DELETE /v1/finance/transactions/tx-settle-2': (_) => (200, {'meta': <String, Object>{}}),
    });
    await pumpFinance(tester, const SharedScreen(), api);

    await tester.tap(find.text('Liquidar'));
    await tester.pumpAndSettle();
    expect(find.text('Liquidar con Ana'), findsOneWidget);
    expect(find.text('Ana te paga'), findsOneWidget);
    expect(find.text('+40,00$nbsp€'), findsOneWidget);
    expect(find.text('BBVA'), findsOneWidget);

    await tester.tap(find.text('Registrar cobro'));
    await tester.pumpAndSettle();

    expect(bodyOf(api, 'POST', '/v1/finance/contacts/ana/settle'), {
      'account_id': 'acc-main',
      'date': isoDate(today()),
    });
    expect(find.text('Liquidado con Ana: +40,00$nbsp€ en BBVA'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(api.requests.where((request) => request.method == 'DELETE').map((request) => request.path), [
      '/v1/finance/transactions/tx-settle',
      '/v1/finance/transactions/tx-settle-2',
    ]);
  });

  testWidgets('shows the server message when settling fails', (tester) async {
    final api = FakeApi({
      ...contactsRoutes(),
      'POST /v1/finance/contacts/ana/settle': (_) => (
        422,
        {
          'message': 'invalid',
          'errors': {
            'account_id': ['La cuenta no es válida.'],
          },
        },
      ),
    });
    await pumpFinance(tester, const SharedScreen(), api);

    await tester.tap(find.text('Liquidar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar cobro'));
    await tester.pumpAndSettle();

    expect(find.text('La cuenta no es válida.'), findsOneWidget);
    expect(find.text('Liquidar con Ana'), findsOneWidget);
  });

  testWidgets('shows a retry when the contacts cannot load', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/contacts': (_) => (500, {'message': 'boom'}),
    });
    await pumpFinance(tester, const SharedScreen(), api);

    expect(find.text('No se han podido cargar los contactos'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('opens the contact detail from the list', (tester) async {
    final api = FakeApi(contactsRoutes(detail: detailJson(shares: [shareJson()])));
    final container = testContainer(api, storage: {'auth_token': 'stored'});
    final router = GoRouter(
      initialLocation: Routes.shared,
      routes: [
        GoRoute(
          path: Routes.shared,
          builder: (context, state) => const SharedScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => ContactDetailScreen(contactId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: carliTheme(Brightness.light),
          locale: const Locale('es', 'ES'),
          supportedLocales: const [Locale('es', 'ES')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => Material(
            type: MaterialType.transparency,
            child: Stack(children: [child!, const ToastHost()]),
          ),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Te debe 40,00$nbsp€'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.contact('ana'));
    expect(find.text('Cena'), findsOneWidget);
  });

  group('contact detail', () {
    testWidgets('shows the balance, the shared movements and the loans', (tester) async {
      final api = FakeApi(
        contactsRoutes(
          detail: detailJson(
            contact: contactJson(owedToMe: 30000, balance: 34000, notes: 'Compañera de piso'),
            shares: [
              shareJson(),
              shareJson(id: 's-2', settled: true, amount: 1500, payee: null, date: DateTime(2026, 9, 3)),
            ],
            debts: [debtJson()],
          ),
        ),
      );
      await pumpFinance(tester, const ContactDetailScreen(contactId: 'ana'), api);

      expect(find.text('Ana'), findsWidgets);
      expect(tester.widget<Text>(find.text('Te debe 340,00$nbsp€')).style?.color, CarliColors.light.positive);
      expect(find.text('Gastos compartidos sin liquidar'), findsOneWidget);
      expect(find.text('Préstamos que te debe'), findsOneWidget);
      expect(find.text('Préstamos que le debes'), findsNothing);
      expect(find.text('Compañera de piso'), findsOneWidget);
      expect(find.text('Cena'), findsOneWidget);
      expect(find.text('Hoy · total 80,00$nbsp€'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Gasto compartido'), findsOneWidget);
      expect(find.text('Liquidado'), findsOneWidget);
      expect(tester.widget<Text>(find.text('+15,00$nbsp€')).style?.color, CarliColors.light.text2);
      await tester.scrollUntilVisible(find.text('Préstamo coche'), 200);
      expect(find.text('Te deben · vence 3 nov'), findsOneWidget);
      expect(find.text('Préstamos'), findsOneWidget);
      expect(find.bySemanticsLabel('Liquidar'), findsOneWidget);
    });

    testWidgets('explains how to share when there are no movements yet', (tester) async {
      final api = FakeApi(contactsRoutes(detail: detailJson(contact: contactJson(balance: 0, sharesPending: 0))));
      await pumpFinance(tester, const ContactDetailScreen(contactId: 'ana'), api);

      expect(find.text('Sin gastos compartidos'), findsOneWidget);
      expect(find.text('Al registrar un gasto, actívale “Gasto compartido” y elige a Ana.'), findsOneWidget);
      expect(find.text('En paz'), findsOneWidget);
      expect(find.bySemanticsLabel('Liquidar'), findsNothing);
    });

    testWidgets('tells when the contact no longer exists', (tester) async {
      final api = FakeApi({
        ...financeBaseRoutes(),
        'GET /v1/finance/contacts/gone': (_) => (404, {'message': 'x'}),
      });
      await pumpFinance(tester, const ContactDetailScreen(contactId: 'gone'), api);

      expect(find.text('No encontramos este contacto'), findsOneWidget);
      expect(find.text('Volver a compartidos'), findsOneWidget);
    });

    testWidgets('edits the name and notes', (tester) async {
      final api = FakeApi({
        ...contactsRoutes(detail: detailJson(shares: [shareJson()])),
        'PATCH /v1/finance/contacts/ana': (_) => (200, {'data': detailJson(contact: contactJson(name: 'Ana M.'))}),
      });
      await pumpFinance(tester, const ContactDetailScreen(contactId: 'ana'), api);

      await tester.tap(find.bySemanticsLabel('Editar contacto'));
      await tester.pumpAndSettle();
      expect(find.text('Editar contacto'), findsOneWidget);
      expect(find.text('Eliminar'), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), 'Ana M.');
      await tester.enterText(find.byType(TextField).at(1), 'Piso');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(bodyOf(api, 'PATCH', '/v1/finance/contacts/ana'), {'name': 'Ana M.', 'notes': 'Piso'});
      expect(find.text('Contacto actualizado'), findsOneWidget);
      expect(
        api.requests.where((request) => request.path == '/v1/finance/contacts/ana' && request.method == 'GET').length,
        2,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('archives with undo', (tester) async {
      final api = FakeApi({
        ...contactsRoutes(detail: detailJson(shares: [shareJson()])),
        'PATCH /v1/finance/contacts/ana': (options) =>
            (200, {'data': detailJson(contact: contactJson(archived: (options.data as Json)['archived'] as bool))}),
      });
      await pumpFinance(tester, const ContactDetailScreen(contactId: 'ana'), api);

      await tester.tap(find.bySemanticsLabel('Editar contacto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar'));
      await tester.pumpAndSettle();

      expect(bodyOf(api, 'PATCH', '/v1/finance/contacts/ana'), {'archived': true});
      expect(find.text('Ana archivado'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(bodyOf(api, 'PATCH', '/v1/finance/contacts/ana'), {'archived': false});
    });

    testWidgets('deletes a contact without movements and recreates it on undo', (tester) async {
      final api = FakeApi({
        ...contactsRoutes(
          detail: detailJson(contact: contactJson(notes: 'Piso', balance: 0, sharesPending: 0)),
        ),
        'DELETE /v1/finance/contacts/ana': (_) => (204, null),
        'POST /v1/finance/contacts': (_) => (201, {'data': detailJson(contact: contactJson(id: 'ana-2'))}),
      });
      await pumpFinance(tester, const ContactDetailScreen(contactId: 'ana'), api);

      await tester.tap(find.bySemanticsLabel('Editar contacto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((request) => request.method == 'DELETE').single.path, '/v1/finance/contacts/ana');
      expect(find.text('Ana eliminado'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(bodyOf(api, 'POST', '/v1/finance/contacts'), {'name': 'Ana', 'notes': 'Piso'});
    });
  });
}
