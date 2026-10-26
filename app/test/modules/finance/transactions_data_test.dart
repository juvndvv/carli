import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/format/dates.dart';
import 'package:carli/modules/finance/data/finance_api.dart';
import 'package:carli/modules/finance/data/finance_providers.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/data/models.dart';
import 'package:carli/modules/finance/data/transaction_filters.dart';
import 'package:carli/modules/finance/data/transactions_list.dart';
import 'package:carli/modules/finance/data/transactions_repository.dart';

import '../../support/fake_api.dart';
import '../../support/finance_fixtures.dart';
import '../../support/test_app.dart';

Transaction tx(Map<String, Object?> patch) => Transaction.fromJson({...transactionJson(), ...patch});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('filters', () {
    test('send the current period id unless a period or all periods are chosen', () {
      expect(const TransactionFilters().toApiQuery('p-oct')['period_id'], 'p-oct');
      expect(const TransactionFilters(periodScope: PeriodScope.all).toApiQuery('p-oct')['period_id'], isNull);
      expect(
        const TransactionFilters(periodScope: PeriodScope.specific, periodId: 'p-sep').toApiQuery('p-oct')['period_id'],
        'p-sep',
      );
    });

    test('encode lists as array parameters and drop empty values', () {
      final query = const TransactionFilters(
        accountIds: {'b', 'a'},
        kinds: {TransactionKind.expense},
        query: '  café ',
        uncategorized: true,
      ).toApiQuery(null);

      expect(toQueryParameters(query), {
        'account_id[]': ['a', 'b'],
        'kind[]': ['expense'],
        'q': 'café',
        'uncategorized': '1',
      });
    });

    test('compare by value so providers are shared', () {
      expect(const TransactionFilters(accountIds: {'a', 'b'}), TransactionFilters(accountIds: {'b', 'a'}));
      expect(const TransactionFilters(uncategorized: true).activeCount, 1);
      expect(const TransactionFilters(uncategorized: true).onlyUncategorized, isTrue);
      expect(const TransactionFilters(uncategorized: true, query: 'x').cleared().uncategorized, isFalse);
    });
  });

  group('groupByDay', () {
    test('groups consecutive days and totals them without transfers', () {
      final day = today();
      final groups = groupByDay([
        tx({'id': '1', 'date': isoDate(day), 'amount_cents': -1000}),
        tx({'id': '2', 'date': isoDate(day), 'amount_cents': -500, 'kind': 'transfer'}),
        tx({'id': '3', 'date': isoDate(day.subtract(const Duration(days: 1))), 'amount_cents': 2000}),
      ], hideIncomingTransfers: true);

      expect(groups, hasLength(2));
      expect(groups.first.items, hasLength(2));
      expect(groups.first.total, -1000);
      expect(groups.last.total, 2000);
    });

    test('hides the incoming side of a transfer when both sides are listed', () {
      final items = [
        tx({'id': 'out', 'kind': 'transfer', 'amount_cents': -500, 'transfer_group_id': 'g'}),
        tx({'id': 'in', 'kind': 'transfer', 'amount_cents': 500, 'transfer_group_id': 'g'}),
      ];

      expect(groupByDay(items, hideIncomingTransfers: true).single.items.map((item) => item.id), ['out']);
      expect(groupByDay(items, hideIncomingTransfers: false).single.items, hasLength(2));
    });
  });

  group('transaction list', () {
    test('loads the current period with the pending count and pages with the cursor', () async {
      final api = FakeApi({
        ...financeBaseRoutes(),
        'GET /v1/finance/transactions': (options) {
          final params = options.queryParameters;
          if (params['status'] == 'pending') return (200, transactionPage(const [], count: 3));
          if (params['cursor'] == 'next') {
            return (200, transactionPage([transactionJson(id: 'tx-1'), transactionJson(id: 'tx-2')]));
          }
          return (200, transactionPage([transactionJson(id: 'tx-1')], hasMore: true, cursor: 'next'));
        },
      });
      final container = testContainer(api, storage: {'auth_token': 'stored'});
      const filters = TransactionFilters();

      final first = await container.read(transactionListProvider(filters).future);
      expect(first.items.map((item) => item.id), ['tx-1']);
      expect(first.pendingCount, 3);
      expect(
        api.requests.firstWhere((r) => r.path == '/v1/finance/transactions').queryParameters['period_id'],
        'p-oct',
      );

      await container.read(transactionListProvider(filters).notifier).loadMore();
      final state = container.read(transactionListProvider(filters)).requireValue;
      expect(state.items.map((item) => item.id), ['tx-1', 'tx-2']);
      expect(state.hasMore, isFalse);
    });

    test('reloads lists, accounts and budgets after a mutation, like FinanceChanges', () async {
      var listCalls = 0;
      var accountCalls = 0;
      final api = FakeApi({
        ...financeBaseRoutes(),
        'GET /v1/finance/accounts': (_) {
          accountCalls++;
          return (
            200,
            {
              'data': [accountJson()],
              'meta': {'net_worth_cents': 0},
            },
          );
        },
        'GET /v1/finance/transactions': (options) {
          if (options.queryParameters['status'] != 'pending') listCalls++;
          return (200, transactionPage([transactionJson()]));
        },
        'DELETE /v1/finance/transactions/tx-1': (_) => (
          200,
          {
            'meta': {'periods_changed': true},
          },
        ),
      });
      final container = testContainer(api, storage: {'auth_token': 'stored'});
      container.listen(transactionListProvider(const TransactionFilters()), (_, _) {});
      container.listen(accountsProvider, (_, _) {});
      await container.read(transactionListProvider(const TransactionFilters()).future);
      await container.read(accountsProvider.future);

      final periodsChanged = await container.read(transactionsRepositoryProvider).remove('tx-1');
      await container.read(transactionListProvider(const TransactionFilters()).future);
      await container.read(accountsProvider.future);

      expect(periodsChanged, isTrue);
      expect(listCalls, 2);
      expect(accountCalls, 2);
    });
  });

  test('signs amounts by kind', () {
    expect(signedAmount(TransactionKind.expense, 4250), -4250);
    expect(signedAmount(TransactionKind.income, -4250), 4250);
    expect(signedAmount(TransactionKind.adjustment, -100), -100);
  });

  test('parses the accounts payload with net worth', () async {
    final container = testContainer(FakeApi(financeBaseRoutes()), storage: {'auth_token': 'stored'});
    final accounts = await container.read(accountsProvider.future);
    expect(accounts.netWorthCents, 123456);
    expect(accounts.active.single.name, 'BBVA');
    expect(container.read(financeApiProvider), isA<FinanceApi>());
  });

  test('indexes categories with parents and inherited icons', () {
    final index = CategoryIndex([
      Category.fromJson(categoryJson('home', 'Casa', icon: 'house', children: [categoryJson('rent', 'Alquiler')])),
    ]);
    expect(index.find('rent')?.label, 'Casa › Alquiler');
    expect(index.find('rent')?.icon, 'house');
    expect(index.selectable(CategoryKind.expense), hasLength(2));
  });
}
