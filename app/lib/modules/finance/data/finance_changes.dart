import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FinanceScope { transactions, accounts, categories, tags, budgets, periods, settings, contacts, bank, rules }

const transactionSideEffects = [
  FinanceScope.transactions,
  FinanceScope.accounts,
  FinanceScope.periods,
  FinanceScope.budgets,
  FinanceScope.tags,
  FinanceScope.contacts,
];

final financeChangesProvider = NotifierProvider<FinanceChanges, Map<FinanceScope, int>>(FinanceChanges.new);

class FinanceChanges extends Notifier<Map<FinanceScope, int>> {
  @override
  Map<FinanceScope, int> build() => const {};

  void notify(Iterable<FinanceScope> scopes) {
    state = {...state, for (final scope in scopes.toSet()) scope: (state[scope] ?? 0) + 1};
  }

  void notifyTransactions() => notify(transactionSideEffects);

  void refreshAll() => notify(FinanceScope.values);
}

extension WatchFinanceChanges on Ref {
  void watchFinance(Iterable<FinanceScope> scopes) {
    for (final scope in scopes) {
      watch(financeChangesProvider.select((versions) => versions[scope] ?? 0));
    }
  }
}
