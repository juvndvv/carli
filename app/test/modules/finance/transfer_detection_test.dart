import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/bank.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/screens/transaction_sheet.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';
import '../../support/finance_fixtures.dart';

class _Opener extends StatelessWidget {
  const _Opener({required this.transaction});

  final Transaction transaction;

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

Json _importedJson({String kind = 'expense', int amount = -50000}) => {
  ...transactionJson(kind: kind, amount: amount, categoryId: null, source: 'bank'),
  'bank': {'aspsp_name': 'BBVA'},
};

Json _detectedJson({String source = 'auto'}) => {
  ..._importedJson(),
  'kind': 'transfer',
  'transfer_group_id': 'group-1',
  'transfer_account_id': 'acc-revolut',
  'transfer_source': source,
  'transfer_detected_at': '2026-10-24T10:00:00+02:00',
  'transfer_undoable': true,
};

Json _linkedAccountJson(String id, String name) => {
  ...accountJson(id: id, name: name),
  'bank': {'connection_id': 'conn-$id', 'aspsp_name': name},
};

Future<void> _open(WidgetTester tester, Transaction transaction, FakeApi api) async {
  await pumpFinance(tester, _Opener(transaction: transaction), api);
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  await settle(tester);
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).last);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await settle(tester);
}

void main() {
  test('parses how a transfer was created and whether it can be undone', () {
    final detected = Transaction.fromJson(_detectedJson());
    final manual = Transaction.fromJson(transactionJson());

    expect(detected.transferSource, TransferSource.auto);
    expect(detected.transferUndoable, isTrue);
    expect(manual.transferSource, isNull);
    expect(manual.transferUndoable, isFalse);
    expect(Transaction.fromJson(_importedJson()).canBecomeTransfer, isTrue);
    expect(manual.canBecomeTransfer, isFalse);
  });

  test('names new accounts after the bank account label', () {
    BankAccountCandidate candidate(Json extra) => BankAccountCandidate.fromJson({
      'external_account_uid': 'uid',
      'name': 'Juan Daniel Forner Garriga',
      'iban': null,
      'currency': 'EUR',
      'suggested_account_type': 'savings',
      'linked_account': null,
      ...extra,
    });

    final pocket = candidate({'short_name': 'Gastos', 'suggested_name': 'Revolut · Gastos'});
    expect(candidateTitle(pocket), 'Gastos');
    expect(defaultNewAccountName('Revolut', pocket), 'Revolut · Gastos');
    expect(candidateTitle(candidate(const {})), 'Juan Daniel Forner Garriga');
    expect(defaultNewAccountName('Revolut', candidate(const {})), 'Revolut Juan Daniel Forner Garriga');
  });

  test('mentions detected transfers after a sync', () {
    BankConnection connection(int transfers) => BankConnection.fromJson({
      'id': 'conn-1',
      'aspsp_name': 'BBVA',
      'status': 'active',
      'expires_in_days': 80,
      'last_synced_at': null,
      'last_error': null,
      'linked_accounts': <Json>[],
      'last_sync_transfers': transfers,
    });

    expect(syncedMessage(connection(0)), 'BBVA sincronizado');
    expect(syncedMessage(connection(1)), 'BBVA sincronizado · 1 transferencia entre tus cuentas detectada');
    expect(syncedMessage(connection(3)), 'BBVA sincronizado · 3 transferencias entre tus cuentas detectadas');
  });

  testWidgets('explains a detected transfer and undoes it', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'POST /v1/finance/transactions/tx-1/undo-transfer': (_) => (
        200,
        {
          'data': [_importedJson()],
        },
      ),
    });
    await _open(tester, Transaction.fromJson(_detectedJson()), api);

    expect(find.textContaining('Detectada como transferencia entre tus cuentas'), findsOneWidget);
    expect(find.text('Es una transferencia a…'), findsNothing);
    await _tapButton(tester, 'Deshacer transferencia');

    expect(
      api.requests.where((request) => request.path == '/v1/finance/transactions/tx-1/undo-transfer'),
      hasLength(1),
    );
    expect(find.text('Transferencia deshecha · no se volverá a sugerir'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('turns an import into a transfer to a manual account and offers to undo it', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(
        accounts: [
          _linkedAccountJson('acc-main', 'BBVA'),
          _linkedAccountJson('acc-revolut', 'Revolut'),
          accountJson(id: 'acc-myinvestor', name: 'MyInvestor', type: 'savings'),
        ],
      ),
      'POST /v1/finance/transactions/tx-1/convert-to-transfer': (_) => (
        201,
        {
          'data': {
            'transfer_group_id': 'group-1',
            'from': _detectedJson(source: 'linked'),
            'to': {
              ...transactionJson(id: 'tx-2', amount: 50000, kind: 'transfer', categoryId: null),
              'transfer_source': 'linked',
              'transfer_undoable': true,
            },
          },
        },
      ),
      'POST /v1/finance/transactions/tx-1/undo-transfer': (_) => (
        200,
        {
          'data': [_importedJson()],
        },
      ),
    });
    await _open(tester, Transaction.fromJson(_importedJson()), api);

    await _tapButton(tester, 'Es una transferencia a…');
    expect(find.text('Transferencia a…'), findsOneWidget);
    expect(find.text('Revolut'), findsNothing);
    await tester.tap(find.text('MyInvestor'));
    await tester.pumpAndSettle();
    await settle(tester);

    final convert = api.requests.singleWhere((request) => request.path.endsWith('/convert-to-transfer'));
    expect(convert.data, {'account_id': 'acc-myinvestor'});
    expect(find.text('Transferencia a MyInvestor'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(api.requests.where((request) => request.path.endsWith('/undo-transfer')), hasLength(1));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('offers a transfer from a manual account for imported income', (tester) async {
    final api = FakeApi(
      financeBaseRoutes(
        accounts: [
          _linkedAccountJson('acc-main', 'BBVA'),
          accountJson(id: 'acc-myinvestor', name: 'MyInvestor', type: 'savings'),
        ],
      ),
    );
    await _open(tester, Transaction.fromJson(_importedJson(kind: 'income', amount: 20000)), api);

    expect(find.text('Es una transferencia desde…'), findsOneWidget);
  });

  testWidgets('does not offer the action without manual accounts', (tester) async {
    final api = FakeApi(
      financeBaseRoutes(
        accounts: [_linkedAccountJson('acc-main', 'BBVA'), _linkedAccountJson('acc-revolut', 'Revolut')],
      ),
    );
    await _open(tester, Transaction.fromJson(_importedJson()), api);

    expect(find.text('Es una transferencia a…'), findsNothing);
    expect(find.text('Deshacer transferencia'), findsNothing);
  });
}
