import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/files/file_sharer.dart';
import 'package:carli/core/format/dates.dart';
import 'package:carli/modules/finance/screens/transactions_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';

FakeApi transactionsApi({List<Map<String, Object?>>? items, Map<String, FakeRoute> extra = const {}}) => FakeApi({
  ...financeBaseRoutes(),
  'GET /v1/finance/transactions': (options) => options.queryParameters['status'] == 'pending'
      ? (200, transactionPage(const [], count: 2))
      : (
          200,
          transactionPage(
            items ??
                [
                  transactionJson(id: 'tx-1'),
                  transactionJson(
                    id: 'tx-2',
                    payee: 'Nómina',
                    amount: 269500,
                    kind: 'income',
                    date: today().subtract(const Duration(days: 1)),
                  ),
                ],
          ),
        ),
  ...extra,
});

void main() {
  toolsTests();
  testWidgets('groups movements by day with relative headers and totals', (tester) async {
    await pumpFinance(tester, const TransactionsScreen(), transactionsApi());

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('Mercadona'), findsOneWidget);
    expect(find.text('2 movimientos'), findsOneWidget);
    expect(find.text('Pendientes (2)'), findsOneWidget);
    expect(find.text('+2.695,00 €'), findsWidgets);
  });

  testWidgets('filters uncategorized movements from the chip', (tester) async {
    final api = transactionsApi();
    await pumpFinance(tester, const TransactionsScreen(), api);

    await tester.ensureVisible(find.text('Sin categoría'));
    await tester.tap(find.text('Sin categoría'));
    await settle(tester);

    expect(api.requests.where((r) => r.path == '/v1/finance/transactions').last.queryParameters['uncategorized'], '1');
  });

  testWidgets('offers the first movement when the list is empty', (tester) async {
    await pumpFinance(tester, const TransactionsScreen(), transactionsApi(items: const []));

    expect(find.text('Aún no hay movimientos'), findsOneWidget);
    expect(find.text('Añadir movimiento'), findsOneWidget);
  });

  testWidgets('shows an error with retry when the list fails', (tester) async {
    var fail = true;
    final api = transactionsApi(
      extra: {
        'GET /v1/finance/transactions': (_) =>
            fail ? (500, {'message': 'Server Error'}) : (200, transactionPage(const [])),
      },
    );
    await pumpFinance(tester, const TransactionsScreen(), api);

    expect(find.text('No se han podido cargar los movimientos'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Reintentar'));
    await settle(tester);

    expect(find.text('Aún no hay movimientos'), findsOneWidget);
  });

  testWidgets('deletes with a swipe and restores with Deshacer', (tester) async {
    final api = transactionsApi(
      extra: {
        'DELETE /v1/finance/transactions/tx-1': (_) => (
          200,
          {
            'meta': {'periods_changed': false},
          },
        ),
        'POST /v1/finance/transactions/tx-1/restore': (_) => (200, {'data': transactionJson(), 'meta': {}}),
      },
    );
    await pumpFinance(tester, const TransactionsScreen(), api);

    await tester.fling(find.byType(Dismissible).first, const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    await settle(tester);

    expect(api.requests.any((r) => r.method == 'DELETE' && r.path == '/v1/finance/transactions/tx-1'), isTrue);
    expect(find.text('Movimiento eliminado'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);

    expect(api.requests.any((r) => r.method == 'POST' && r.path.endsWith('/restore')), isTrue);
    expect(find.text('Mercadona'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}

class RecordingSharer implements FileSharer {
  final shared = <({String fileName, List<int> bytes, String mimeType})>[];

  @override
  Future<void> share({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    Rect? origin,
  }) async => shared.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
}

void toolsTests() {
  testWidgets('selects movements and edits them in bulk', (tester) async {
    final api = transactionsApi(
      extra: {
        'PATCH /v1/finance/transactions/bulk': (_) => (
          200,
          {
            'data': {'updated': 2},
          },
        ),
      },
    );
    await pumpFinance(tester, const TransactionsScreen(), api);

    await tester.tap(find.text('Seleccionar'));
    await tester.pump();
    await tester.tap(find.text('Mercadona'));
    await tester.tap(find.text('Nómina'));
    await tester.pump();
    expect(find.text('2 seleccionados'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estado'));
    await tester.pump();
    await tester.tap(find.text('Pendiente'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await settle(tester);

    final body = api.requests.singleWhere((r) => r.path == '/v1/finance/transactions/bulk').data as Map;
    expect(body['ids'], unorderedEquals(['tx-1', 'tx-2']));
    expect(body['status'], 'pending');
    expect(find.text('2 movimientos actualizados'), findsOneWidget);
    expect(find.text('Seleccionar'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('filters by tag', (tester) async {
    final api = transactionsApi();
    await pumpFinance(tester, const TransactionsScreen(), api);

    await tester.ensureVisible(find.text('Etiqueta'));
    await tester.tap(find.text('Etiqueta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#viaje'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await settle(tester);

    final last = api.requests.where((r) => r.path == '/v1/finance/transactions').last;
    expect(last.queryParameters['tag[]'], ['viaje']);
  });

  testWidgets('exports the filtered movements as CSV through the share sheet', (tester) async {
    final sharer = RecordingSharer();
    final api = transactionsApi(extra: {'GET /v1/finance/transactions/export.csv': (_) => (200, 'fecha;importe')});
    await pumpFinance(
      tester,
      const TransactionsScreen(),
      api,
      overrides: [fileSharerProvider.overrideWithValue(sharer)],
    );

    await tester.tap(find.bySemanticsLabel('Exportar CSV'));
    await settle(tester);

    expect(api.requests.last.queryParameters['period_id'], 'p-oct');
    expect(sharer.shared.single.fileName, startsWith('movimientos-'));
    expect(sharer.shared.single.mimeType, 'text/csv');
  });
}
