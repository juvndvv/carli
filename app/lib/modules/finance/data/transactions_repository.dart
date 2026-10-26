import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance_api.dart';
import 'finance_changes.dart';
import 'json.dart';
import 'models.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(financeApiProvider), ref.read(financeChangesProvider.notifier)),
);

class TransactionsRepository {
  TransactionsRepository(this._api, this._changes);

  final FinanceApi _api;
  final FinanceChanges _changes;

  Future<T> _mutating<T>(Future<T> Function() action) async {
    final result = await action();
    _changes.notifyTransactions();
    return result;
  }

  Future<Saved<Transaction>> create(Json input) => _mutating(() => _api.createTransaction(input));

  Future<Saved<Transaction>> update(String id, Json input) => _mutating(() => _api.updateTransaction(id, input));

  Future<bool> remove(String id) => _mutating(() => _api.deleteTransaction(id));

  Future<Saved<Transaction>> restore(String id) => _mutating(() => _api.restoreTransaction(id));

  Future<Transaction> transfer(Json input) => _mutating(() => _api.transfer(input));

  Future<int> bulkUpdate(Json input) => _mutating(() => _api.bulkUpdate(input));

  Future<List<int>> exportCsv(Query query) => _api.exportTransactions(query);

  Future<List<PayeeSuggestion>> suggestPayees(String query, CategoryKind kind) => _api.suggestPayees(query, kind);
}

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(ref.watch(financeApiProvider), ref.read(financeChangesProvider.notifier)),
);

class BudgetsRepository {
  BudgetsRepository(this._api, this._changes);

  final FinanceApi _api;
  final FinanceChanges _changes;

  Future<BudgetOverview> upsert(String periodId, List<Json> budgets) async {
    final result = await _api.upsertBudgets(periodId, budgets);
    _changes.notify(const [FinanceScope.budgets]);
    return result;
  }

  Future<BudgetOverview> copy({required String from, required String to}) async {
    final result = await _api.copyBudgets(from: from, to: to);
    _changes.notify(const [FinanceScope.budgets]);
    return result;
  }
}

Cents signedAmount(TransactionKind kind, Cents magnitude) => switch (kind) {
  TransactionKind.expense => -magnitude.abs(),
  TransactionKind.income || TransactionKind.transfer => magnitude.abs(),
  TransactionKind.adjustment => magnitude,
};
