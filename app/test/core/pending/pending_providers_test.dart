import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/pending/pending_models.dart';
import 'package:carli/core/pending/pending_providers.dart';
import 'package:carli/core/pending/pending_types.dart';
import 'package:carli/modules/finance/data/finance_changes.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';
import 'pending_fixtures.dart';

const _summaryRoute = 'GET /v1/pending/summary';
const _listRoute = 'GET /v1/pending';

ProviderContainer _container(FakeApi api) {
  final container = testContainer(api, storage: {'auth_token': 'stored'});
  addTearDown(container.dispose);
  return container;
}

int _calls(FakeApi api, String path) => api.requests.where((request) => request.path == path).length;

void main() {
  group('pending models', () {
    test('parse the summary and count by module and type', () {
      final summary = PendingSummary.fromJson(pendingSummaryJson()['data'] as PendingJson);
      expect(summary.total, 3);
      expect(summary.count('finance'), 3);
      expect(summary.count('finance', 'recurring_to_confirm'), 1);
    });

    test('drop an entry once its last item is resolved', () {
      final summary = PendingSummary.fromJson(pendingSummaryJson(uncategorized: 1)['data'] as PendingJson);
      final next = summary.without(pendingItem());
      expect(next.total, 1);
      expect(next.entries.map((entry) => entry.type), ['recurring_to_confirm']);
      expect(next.without(pendingItem(type: 'other')).total, 1);
    });

    test('label totals and describe unknown types with a readable fallback', () {
      expect(pendingTotalLabel(0), 'Nada por revisar');
      expect(pendingTotalLabel(1), '1 elemento por revisar');
      expect(pendingTotalLabel(8), '8 elementos por revisar');
      final fallback = fallbackPendingDescriptor('overdue_task');
      expect(fallback.label, 'Overdue task');
      expect(fallback.icon, 'inbox');
      expect(fallback.countLabel(1), '1 pendiente');
      expect(fallback.countLabel(4), '4 pendientes');
      expect(fallbackPendingDescriptor('').label, 'Pendientes');
      final registry = PendingTypeRegistry({FinancePendingTypes.module: financePendingModule});
      expect(registry.describe('finance', 'recurring_to_confirm').countLabel(2), '2 recurrentes por confirmar');
      expect(registry.describe('finance', 'uncategorized_transaction').countLabel(1), '1 movimiento por categorizar');
    });

    test('build filter query parameters', () {
      expect(PendingFilter.all.queryParameters, isEmpty);
      expect(const PendingFilter(module: 'finance', type: 'recurring_to_confirm').queryParameters, {
        'modulo': 'finance',
        'tipo': 'recurring_to_confirm',
      });
    });
  });

  group('pendingSummaryProvider', () {
    test('loads the summary and exposes the total', () async {
      final api = FakeApi({_summaryRoute: (_) => (200, pendingSummaryJson())});
      final container = _container(api);
      container.listen(pendingTotalProvider, (_, _) {});

      await container.read(pendingSummaryProvider.future);
      expect(container.read(pendingTotalProvider), 3);
      expect(container.read(pendingEntriesProvider), hasLength(2));
    });

    test('keeps the previous summary when a refresh fails', () async {
      var fail = false;
      final api = FakeApi({
        _summaryRoute: (_) => fail ? (500, {'message': 'boom'}) : (200, pendingSummaryJson()),
      });
      final container = _container(api);
      await container.read(pendingSummaryProvider.future);

      fail = true;
      expect(await container.read(pendingSummaryProvider.notifier).refresh(), isNull);
      expect(container.read(pendingTotalProvider), 3);
    });

    test('keeps the previous total when a finance-triggered reload fails', () async {
      var fail = false;
      final api = FakeApi({
        _summaryRoute: (_) => fail ? (500, {'message': 'boom'}) : (200, pendingSummaryJson()),
      });
      final container = _container(api);
      container.listen(pendingTotalProvider, (_, _) {});
      await container.read(pendingSummaryProvider.future);

      fail = true;
      container.read(financeChangesProvider.notifier).notifyTransactions();
      await expectLater(container.read(pendingSummaryProvider.future), throwsA(anything));
      expect(container.read(pendingTotalProvider), 3);
    });

    test('skips a refresh while the summary is fresh', () async {
      final api = FakeApi({_summaryRoute: (_) => (200, pendingSummaryJson())});
      final container = _container(api);
      await container.read(pendingSummaryProvider.future);

      await container.read(pendingSummaryProvider.notifier).refreshIfStale();
      expect(_calls(api, '/v1/pending/summary'), 1);
      await container.read(pendingSummaryProvider.notifier).refreshIfStale(maxAge: Duration.zero);
      expect(_calls(api, '/v1/pending/summary'), 2);
    });

    test('refreshes when transactions or recurring rules change', () async {
      var uncategorized = 2;
      final api = FakeApi({_summaryRoute: (_) => (200, pendingSummaryJson(uncategorized: uncategorized))});
      final container = _container(api);
      container.listen(pendingSummaryProvider, (_, _) {});
      await container.read(pendingSummaryProvider.future);

      uncategorized = 0;
      container.read(financeChangesProvider.notifier).notify(const [FinanceScope.recurring]);
      await container.read(pendingSummaryProvider.future);
      expect(container.read(pendingTotalProvider), 1);

      container.read(financeChangesProvider.notifier).notify(const [FinanceScope.tags]);
      await Future<void>.delayed(Duration.zero);
      expect(_calls(api, '/v1/pending/summary'), 2);
    });

    test('reports the current pending count for reminders', () async {
      var fail = false;
      final api = FakeApi({
        _summaryRoute: (_) => fail ? (500, {'message': 'boom'}) : (200, pendingSummaryJson(uncategorized: 4)),
      });
      final container = _container(api);

      expect(await currentPendingCount(container.read), 5);
      fail = true;
      expect(await currentPendingCount(container.read), isNull);
    });
  });

  group('pendingListProvider', () {
    test('loads a filtered page and follows the cursor without duplicates', () async {
      final api = FakeApi({
        _listRoute: (options) => options.queryParameters['cursor'] == 'c1'
            ? (200, pendingPageJson([pendingItemJson(), pendingItemJson(id: 'tx-2')]))
            : (200, pendingPageJson([pendingItemJson()], cursor: 'c1')),
      });
      final container = _container(api);
      const filter = PendingFilter(module: 'finance', type: 'uncategorized_transaction');
      container.listen(pendingListProvider(filter), (_, _) {});

      final first = await container.read(pendingListProvider(filter).future);
      expect(api.requests.first.queryParameters, {'module': 'finance', 'type': 'uncategorized_transaction'});
      expect(first.hasMore, isTrue);

      await container.read(pendingListProvider(filter).notifier).loadMore();
      expect(api.requests.last.queryParameters['cursor'], 'c1');
      final state = container.read(pendingListProvider(filter)).value!;
      expect(state.items.map((item) => item.id), ['tx-1', 'tx-2']);
      expect(state.hasMore, isFalse);
    });

    test('keeps the loaded items and explains when the next page fails', () async {
      final api = FakeApi({
        _listRoute: (options) => options.queryParameters['cursor'] == 'c1'
            ? (500, {'message': 'boom'})
            : (200, pendingPageJson([pendingItemJson()], cursor: 'c1')),
      });
      final container = _container(api);
      container.listen(pendingListProvider(PendingFilter.all), (_, _) {});
      await container.read(pendingListProvider(PendingFilter.all).future);

      await container.read(pendingListProvider(PendingFilter.all).notifier).loadMore();
      final state = container.read(pendingListProvider(PendingFilter.all)).value!;
      expect(state.items, hasLength(1));
      expect(state.loadingMore, isFalse);
      expect(state.loadMoreError, 'No se han podido cargar más pendientes.');
    });

    test('removes a resolved item, decrements its count and refreshes the summary', () async {
      var uncategorized = 1;
      final api = FakeApi({
        _listRoute: (_) => (200, pendingPageJson([pendingItemJson(), pendingItemJson(id: 'tx-2')])),
        _summaryRoute: (_) => (200, pendingSummaryJson(uncategorized: uncategorized)),
      });
      final container = _container(api);
      container.listen(pendingListProvider(PendingFilter.all), (_, _) {});
      container.listen(pendingSummaryProvider, (_, _) {});
      await container.read(pendingListProvider(PendingFilter.all).future);
      await container.read(pendingSummaryProvider.future);

      uncategorized = 0;
      container.read(pendingListProvider(PendingFilter.all).notifier).resolve(pendingItem());

      expect(container.read(pendingListProvider(PendingFilter.all)).value!.items.map((item) => item.id), ['tx-2']);
      expect(container.read(pendingTotalProvider), 1);
      expect(container.read(pendingEntriesProvider).map((entry) => entry.type), ['recurring_to_confirm']);
      expect(_calls(api, '/v1/pending/summary'), 1);

      await Future<void>.delayed(pendingRefreshDelay + const Duration(milliseconds: 50));
      expect(_calls(api, '/v1/pending/summary'), 2);
    });

    test('loads the next page once the last visible item is resolved', () async {
      final api = FakeApi({
        _listRoute: (options) => options.queryParameters['cursor'] == 'c1'
            ? (200, pendingPageJson([pendingItemJson(id: 'tx-3')]))
            : (200, pendingPageJson([pendingItemJson()], cursor: 'c1')),
        _summaryRoute: (_) => (200, pendingSummaryJson()),
      });
      final container = _container(api);
      container.listen(pendingListProvider(PendingFilter.all), (_, _) {});
      await container.read(pendingListProvider(PendingFilter.all).future);

      container.read(pendingListProvider(PendingFilter.all).notifier).resolve(pendingItem());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(pendingListProvider(PendingFilter.all)).value!.items.map((item) => item.id), ['tx-3']);
    });

    test('reloads when finance transactions change', () async {
      var items = [pendingItemJson(), pendingItemJson(id: 'tx-2')];
      final api = FakeApi({_listRoute: (_) => (200, pendingPageJson(items))});
      final container = _container(api);
      container.listen(pendingListProvider(PendingFilter.all), (_, _) {});
      await container.read(pendingListProvider(PendingFilter.all).future);

      items = [pendingItemJson(id: 'tx-2')];
      container.read(financeChangesProvider.notifier).notifyTransactions();
      final state = await container.read(pendingListProvider(PendingFilter.all).future);
      expect(state.items.map((item) => item.id), ['tx-2']);
    });

    test('exposes the error when the list cannot be loaded', () async {
      final api = FakeApi({
        _listRoute: (_) => (500, {'message': 'boom'}),
      });
      final container = _container(api);
      container.listen(pendingListProvider(PendingFilter.all), (_, _) {});

      await expectLater(container.read(pendingListProvider(PendingFilter.all).future), throwsA(anything));
      expect(container.read(pendingListProvider(PendingFilter.all)).hasError, isTrue);
    });
  });
}
