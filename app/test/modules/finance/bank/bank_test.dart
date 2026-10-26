import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/core/router/router.dart';
import 'package:carli/core/theme/theme.dart';
import 'package:carli/modules/finance/data/bank.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/data/similar_categorization.dart';
import 'package:carli/modules/finance/screens/bank/bank_connections_screen.dart';
import 'package:carli/modules/finance/screens/bank/bank_link_screen.dart';
import 'package:carli/ui/toast.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';
import '../../../support/test_app.dart';

class FakeAuthenticator implements BankAuthenticator {
  FakeAuthenticator(this.result);

  final BankAuthResult result;
  final urls = <String>[];

  @override
  Future<BankAuthResult> authorize(String url) async {
    urls.add(url);
    return result;
  }
}

Json connectionJson({
  String id = 'conn-1',
  String status = 'active',
  int expiresInDays = 80,
  List<Json> linked = const [],
  String? lastError,
}) => {
  'id': id,
  'provider': 'enable_banking',
  'aspsp_name': 'BBVA',
  'aspsp_country': 'ES',
  'status': status,
  'valid_until': '2027-01-23T00:00:00Z',
  'expires_in_days': expiresInDays,
  'last_synced_at': null,
  'last_error': lastError,
  'bank_accounts_count': 2,
  'linked_accounts': linked,
};

Json candidateJson(String uid, {String? name, String? currency = 'EUR', String type = 'checking', Json? linked}) => {
  'external_account_uid': uid,
  'name': name,
  'iban': 'ES91 2100 0418 4502 0005 1332',
  'currency': currency,
  'type': 'CACC',
  'suggested_account_type': type,
  'linked_account': linked,
};

Map<String, FakeRoute> bankRoutes({List<Json>? connections, Map<String, FakeRoute> extra = const {}}) => {
  ...financeBaseRoutes(),
  'GET /v1/finance/bank/connections': (_) => (200, {'data': connections ?? <Json>[]}),
  'GET /v1/finance/category-rules': (_) => (200, {'data': <Json>[]}),
  'GET /v1/finance/bank/aspsps': (options) => (
    200,
    {
      'data': options.queryParameters['country'] == 'ES'
          ? [
              {'name': 'BBVA', 'country': 'ES', 'logo': null, 'consent_days': 90},
              {'name': 'MyInvestor', 'country': 'ES', 'logo': null, 'consent_days': 180},
            ]
          : [
              {'name': 'Revolut', 'country': 'LT', 'logo': null, 'consent_days': 90},
              {'name': 'Swedbank', 'country': 'LT', 'logo': null, 'consent_days': 90},
            ],
    },
  ),
  ...extra,
};

Future<GoRouter> pumpBankRouter(WidgetTester tester, FakeApi api, {required BankAuthenticator authenticator}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = testContainer(
    api,
    storage: {'auth_token': 'stored'},
    overrides: [bankAuthenticatorProvider.overrideWithValue(authenticator)],
  );
  final router = GoRouter(
    initialLocation: Routes.banks,
    routes: [
      GoRoute(
        path: Routes.banks,
        builder: (context, state) => const BankConnectionsScreen(),
        routes: [
          GoRoute(
            path: ':id/vincular',
            builder: (context, state) => BankLinkScreen(
              connectionId: state.pathParameters['id']!,
              renewed: state.uri.queryParameters['renovado'] == '1',
            ),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: carliTheme(Brightness.light),
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: Stack(children: [child!, const ToastHost()]),
        ),
      ),
    ),
  );
  await settle(tester);
  return router;
}

void main() {
  group('helpers', () {
    test('describe the connection state like Angular', () {
      final active = BankConnection.fromJson(connectionJson());
      final soon = BankConnection.fromJson(connectionJson(expiresInDays: 1));
      expect(bankConnectionState(active).label, 'Activa');
      expect(bankConnectionState(soon).label, 'Caduca mañana');
      expect(bankConnectionState(soon).tone, BankTone.warning);
      expect(bankConnectionState(BankConnection.fromJson(connectionJson(status: 'expired'))).canSync, isFalse);
      expect(bankConnectionState(BankConnection.fromJson(connectionJson(status: 'revoked'))).canRenew, isFalse);
    });

    test('merge extra banks, match without accents and mask ibans', () {
      const home = [Aspsp(name: 'MyInvestor', country: 'ES', logo: null, consentDays: 180)];
      const extra = [Aspsp(name: 'Revolut', country: 'LT', logo: null, consentDays: 90)];
      expect(mergeAspsps(home, extra).map((aspsp) => aspsp.name), ['MyInvestor', 'Revolut']);
      expect(matchesAspsp(home.single, 'myinvéstor'), isTrue);
      expect(aspspSubtitle(extra.single), 'LT · Permiso de 90 días');
      expect(maskIban('ES91 2100 0418 4502 0005 1332'), '•••• 1332');
    });

    test('reads the native callback', () {
      final completed = BankAuthResult.fromCallback('carli://bank/callback?connection=abc&renovado=1');
      expect(completed, isA<BankAuthCompleted>());
      expect((completed as BankAuthCompleted).renewed, isTrue);
      final failed = BankAuthResult.fromCallback('carli://bank/callback?error=cancelado');
      expect((failed as BankAuthFailed).message, startsWith('Has cancelado'));
    });

    test('find duplicated link targets but ignore new accounts and skips', () {
      expect(duplicateTargets(['a', 'a', newAccountTarget, newAccountTarget, null, null]), {'a'});
    });

    test('offers similar categorization only for uncategorized entries that got a category', () {
      final original = Transaction.fromJson(transactionJson(categoryId: null, source: 'bank'));
      final saved = Transaction.fromJson(transactionJson(source: 'bank'));
      expect(categorizedImport(original, saved), isTrue);
      expect(categorizedImport(saved, saved), isFalse);
      expect(applySimilarLabel(3), 'Aplicar a los 3 parecidos y recordar');
      expect(appliedMessage(2, 'MERCADONA', 'Comida'), '2 movimientos más en Comida · regla «MERCADONA» guardada');
    });
  });

  testWidgets('invites to connect a bank when there are none', (tester) async {
    await pumpFinance(tester, const BankConnectionsScreen(), FakeApi(bankRoutes()));

    expect(find.text('Conecta tu banco'), findsOneWidget);
    expect(find.text('Reglas de categorización'), findsOneWidget);
  });

  testWidgets('connects from the native app and opens the linking screen', (tester) async {
    final authenticator = FakeAuthenticator(const BankAuthCompleted('conn-1', renewed: false));
    final api = FakeApi(
      bankRoutes(
        extra: {
          'POST /v1/finance/bank/connections': (_) => (
            201,
            {
              'data': {'auth_url': 'https://bank.example/authorize'},
            },
          ),
          'GET /v1/finance/bank/connections/conn-1': (_) => (200, {'data': connectionJson()}),
          'GET /v1/finance/bank/connections/conn-1/accounts': (_) => (
            200,
            {
              'data': [candidateJson('uid-1', name: 'Cuenta Online')],
            },
          ),
        },
      ),
    );
    await pumpBankRouter(tester, api, authenticator: authenticator);

    await tester.tap(find.text('Conectar banco').last);
    await tester.pumpAndSettle();
    expect(find.text('Revolut'), findsOneWidget);
    expect(find.text('Swedbank'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'bbva');
    await tester.pump();
    await tester.tap(find.text('BBVA'));
    await tester.pumpAndSettle();
    await settle(tester);

    final body = api.requests.singleWhere((r) => r.method == 'POST').data as Map;
    expect(body, {'aspsp_name': 'BBVA', 'aspsp_country': 'ES', 'return_to': 'app'});
    expect(authenticator.urls.single, 'https://bank.example/authorize');
    expect(find.text('Vincular cuentas de BBVA'), findsWidgets);
    expect(find.text('Crear cuenta nueva'), findsOneWidget);
  });

  testWidgets('explains why the bank did not connect', (tester) async {
    final api = FakeApi(
      bankRoutes(
        connections: [connectionJson(status: 'expired')],
        extra: {
          'POST /v1/finance/bank/connections/conn-1/renew': (_) => (
            200,
            {
              'data': {'auth_url': 'https://bank.example/renew'},
            },
          ),
        },
      ),
    );
    await pumpBankRouter(tester, api, authenticator: FakeAuthenticator(const BankAuthFailed('cancelado')));

    expect(find.text('Caducada'), findsOneWidget);
    await tester.tap(find.text('Renovar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect((api.requests.singleWhere((r) => r.method == 'POST').data as Map)['return_to'], 'app');
    expect(find.text(bankCallbackErrors['cancelado']!), findsOneWidget);
  });

  testWidgets('links accounts with dates, new accounts and skips', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/bank/connections/conn-1': (_) => (200, {'data': connectionJson()}),
      'GET /v1/finance/bank/connections/conn-1/accounts': (_) => (
        200,
        {
          'data': [candidateJson('uid-1', name: 'Cuenta Online'), candidateJson('uid-2', name: 'USD', currency: 'USD')],
        },
      ),
      'POST /v1/finance/bank/connections/conn-1/accounts': (_) => (200, {'data': connectionJson()}),
    });
    await pumpFinance(tester, const BankLinkScreen(connectionId: 'conn-1'), api);

    expect(find.text('Crear cuenta nueva'), findsOneWidget);
    expect(find.text('No importar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Guardar y sincronizar'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Guardar y sincronizar'));
    await settle(tester);

    final accounts = (api.requests.singleWhere((r) => r.method == 'POST').data as Map)['accounts'] as List;
    expect(accounts.first, {
      'external_account_uid': 'uid-1',
      'account_id': 'new',
      'sync_from_date': isoDate(DateTime.now()),
      'name': 'BBVA Cuenta Online',
      'type': 'checking',
    });
    expect(accounts.last, {'external_account_uid': 'uid-2', 'account_id': null});
    await tester.pump(const Duration(seconds: 40));
  });

  testWidgets('deletes a categorization rule with undo', (tester) async {
    final api = FakeApi(
      bankRoutes(
        extra: {
          'GET /v1/finance/category-rules': (_) => (
            200,
            {
              'data': [
                {
                  'id': 'rule-1',
                  'pattern': 'MERCADONA',
                  'kind': 'expense',
                  'category_id': 'cat-food',
                  'category': {'id': 'cat-food', 'name': 'Comida', 'icon': 'utensils', 'kind': 'expense'},
                },
              ],
            },
          ),
          'DELETE /v1/finance/category-rules/rule-1': (_) => (204, null),
          'POST /v1/finance/category-rules': (_) => (
            201,
            {
              'data': {'id': 'rule-2', 'pattern': 'MERCADONA', 'kind': 'expense', 'category_id': 'cat-food'},
            },
          ),
        },
      ),
    );
    await pumpFinance(tester, const BankConnectionsScreen(), api);

    await tester.scrollUntilVisible(find.text('MERCADONA'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Eliminar la regla MERCADONA',
      ),
    );
    await settle(tester);
    expect(find.text('Regla «MERCADONA» eliminada'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);

    expect((api.requests.singleWhere((r) => r.method == 'POST').data as Map)['pattern'], 'MERCADONA');
  });
}
