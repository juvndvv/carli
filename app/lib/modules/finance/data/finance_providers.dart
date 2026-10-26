import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance_api.dart';
import 'finance_changes.dart';
import 'models.dart';

const fallbackCategoryIcon = 'circle-dashed';

class CategoryEntry {
  const CategoryEntry({required this.category, required this.parent});

  final Category category;
  final Category? parent;

  String get icon => category.icon ?? parent?.icon ?? fallbackCategoryIcon;

  String get label => parent == null ? category.name : '${parent!.name} › ${category.name}';

  bool get selectable => !category.archived && !(parent?.archived ?? false);
}

class CategoryIndex {
  CategoryIndex(this.tree)
    : entries = [
        for (final parent in tree) ...[
          CategoryEntry(category: parent, parent: null),
          for (final child in parent.children) CategoryEntry(category: child, parent: parent),
        ],
      ];

  final List<Category> tree;
  final List<CategoryEntry> entries;

  late final Map<String, CategoryEntry> _byId = {for (final entry in entries) entry.category.id: entry};

  CategoryEntry? find(String? id) => id == null ? null : _byId[id];

  List<Category> topLevel(CategoryKind kind) => [
    for (final category in tree)
      if (category.kind == kind && !category.archived)
        category.withChildren([
          for (final child in category.children)
            if (!child.archived) child,
        ]),
  ];

  List<CategoryEntry> selectable(CategoryKind kind) => [
    for (final entry in entries)
      if (entry.category.kind == kind && entry.selectable) entry,
  ];
}

class AccountsData {
  const AccountsData({required this.all, required this.netWorthCents});

  final List<Account> all;
  final Cents netWorthCents;

  List<Account> get active => [
    for (final account in all)
      if (!account.archived) account,
  ];

  List<Account> get archived => [
    for (final account in all)
      if (account.archived) account,
  ];

  Account? find(String? id) => id == null ? null : all.where((account) => account.id == id).firstOrNull;
}

class PeriodsData {
  const PeriodsData(this.all);

  final List<Period> all;

  Period? get current => all.where((period) => period.isCurrent).firstOrNull ?? all.firstOrNull;

  Period? find(String? id) => id == null ? null : all.where((period) => period.id == id).firstOrNull;

  Period? olderThan(Period period) {
    final index = all.indexWhere((item) => item.id == period.id);
    return index >= 0 && index + 1 < all.length ? all[index + 1] : null;
  }

  Period? newerThan(Period period) {
    final index = all.indexWhere((item) => item.id == period.id);
    return index > 0 ? all[index - 1] : null;
  }
}

final accountsProvider = FutureProvider<AccountsData>((ref) async {
  ref.watchFinance(const [FinanceScope.accounts]);
  final result = await ref.watch(financeApiProvider).accounts();
  return AccountsData(all: result.accounts, netWorthCents: result.netWorth);
});

final categoriesProvider = FutureProvider<CategoryIndex>((ref) async {
  ref.watchFinance(const [FinanceScope.categories]);
  return CategoryIndex(await ref.watch(financeApiProvider).categories());
});

final periodsProvider = FutureProvider<PeriodsData>((ref) async {
  ref.watchFinance(const [FinanceScope.periods]);
  return PeriodsData(await ref.watch(financeApiProvider).periods());
});

final financeSettingsProvider = FutureProvider<FinanceSettings>((ref) async {
  ref.watchFinance(const [FinanceScope.settings, FinanceScope.transactions]);
  return ref.watch(financeApiProvider).settings();
});

final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  ref.watchFinance(const [FinanceScope.tags]);
  return ref.watch(financeApiProvider).tags();
});

final contactOptionsProvider = FutureProvider<List<ContactOption>>((ref) async {
  ref.watchFinance(const [FinanceScope.contacts]);
  return ref.watch(financeApiProvider).contactOptions();
});

final dashboardProvider = FutureProvider.family<Dashboard, String?>((ref, periodId) async {
  ref.watchFinance(FinanceScope.values);
  return ref.watch(financeApiProvider).dashboard(periodId);
});

final financeSummaryProvider = FutureProvider<FinanceSummary>((ref) async {
  ref.watchFinance(FinanceScope.values);
  return ref.watch(financeApiProvider).summary();
});

final budgetsProvider = FutureProvider.family<BudgetOverview, String?>((ref, periodId) async {
  ref.watchFinance(const [FinanceScope.budgets, FinanceScope.transactions]);
  return ref.watch(financeApiProvider).budgets(periodId);
});

final summaryPeriodProvider = NotifierProvider<SelectedPeriod, String?>(SelectedPeriod.new);

final budgetsPeriodProvider = NotifierProvider<SelectedPeriod, String?>(SelectedPeriod.new);

class SelectedPeriod extends Notifier<String?> {
  @override
  String? build() => null;

  void select(Period? period) => state = period == null || period.isCurrent ? null : period.id;
}
