import 'json.dart';

typedef Cents = int;
typedef BasisPoints = int;

enum AccountType { checking, savings, creditCard, cash }

AccountType accountTypeOf(String? value) => switch (value) {
  'savings' => AccountType.savings,
  'credit_card' => AccountType.creditCard,
  'cash' => AccountType.cash,
  _ => AccountType.checking,
};

enum TransactionKind {
  expense('expense', 'Gasto', 'Gastos'),
  income('income', 'Ingreso', 'Ingresos'),
  transfer('transfer', 'Transferencia', 'Transferencias'),
  adjustment('adjustment', 'Ajuste', 'Ajustes');

  const TransactionKind(this.api, this.label, this.plural);

  final String api;
  final String label;
  final String plural;

  static TransactionKind of(String? value) => values.firstWhere((kind) => kind.api == value, orElse: () => expense);
}

enum TransactionStatus {
  pending('pending'),
  cleared('cleared');

  const TransactionStatus(this.api);

  final String api;

  static TransactionStatus of(String? value) => value == 'pending' ? pending : cleared;
}

enum CategoryKind {
  expense('expense'),
  income('income');

  const CategoryKind(this.api);

  final String api;

  static CategoryKind of(String? value) => value == 'income' ? income : expense;
}

enum BudgetStatus { ok, warning, exceeded }

BudgetStatus budgetStatusOf(String? value) => switch (value) {
  'warning' => BudgetStatus.warning,
  'exceeded' => BudgetStatus.exceeded,
  _ => BudgetStatus.ok,
};

class Period {
  const Period({
    required this.id,
    required this.startDate,
    required this.expectedEndDate,
    required this.isCurrent,
    required this.name,
    required this.shortName,
    required this.rangeLabel,
    required this.daysRemaining,
  });

  factory Period.fromJson(Json json) => Period(
    id: json['id'] as String,
    startDate: parseIsoDate(json['start_date'] as String),
    expectedEndDate: parseIsoDateOrNull(json['expected_end_date']),
    isCurrent: json['is_current'] as bool? ?? false,
    name: json['name'] as String? ?? '',
    shortName: json['short_name'] as String? ?? '',
    rangeLabel: json['range_label'] as String? ?? '',
    daysRemaining: intOf(json['days_remaining']),
  );

  final String id;
  final DateTime startDate;
  final DateTime? expectedEndDate;
  final bool isCurrent;
  final String name;
  final String shortName;
  final String rangeLabel;
  final int daysRemaining;
}

class AccountBankLink {
  const AccountBankLink({required this.aspspName});

  factory AccountBankLink.fromJson(Json json) => AccountBankLink(aspspName: json['aspsp_name'] as String? ?? '');

  final String aspspName;
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceCents,
    required this.icon,
    required this.archived,
    this.bank,
  });

  factory Account.fromJson(Json json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: accountTypeOf(json['type'] as String?),
    balanceCents: intOf(json['balance_cents']),
    icon: json['icon'] as String?,
    archived: json['archived'] as bool? ?? false,
    bank: json['bank'] is Json ? AccountBankLink.fromJson(json['bank'] as Json) : null,
  );

  final String id;
  final String name;
  final AccountType type;
  final Cents balanceCents;
  final String? icon;
  final bool archived;
  final AccountBankLink? bank;
}

class AccountRef {
  const AccountRef({required this.id, required this.name});

  factory AccountRef.fromJson(Json json) => AccountRef(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;
}

class CategorySummary {
  const CategorySummary({required this.id, required this.name, required this.icon, required this.kind});

  factory CategorySummary.fromJson(Json json) => CategorySummary(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String?,
    kind: CategoryKind.of(json['kind'] as String?),
  );

  final String id;
  final String name;
  final String? icon;
  final CategoryKind kind;
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.archived,
    this.children = const [],
  });

  factory Category.fromJson(Json json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: CategoryKind.of(json['kind'] as String?),
    icon: json['icon'] as String?,
    archived: json['archived'] as bool? ?? false,
    children: parseList(json['children'], Category.fromJson),
  );

  final String id;
  final String name;
  final CategoryKind kind;
  final String? icon;
  final bool archived;
  final List<Category> children;
}

class TransactionShare {
  const TransactionShare({
    required this.contactId,
    required this.name,
    required this.amountCents,
    required this.settled,
  });

  factory TransactionShare.fromJson(Json json) => TransactionShare(
    contactId: json['contact_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    amountCents: intOf(json['amount_cents']),
    settled: json['settled'] as bool? ?? false,
  );

  final String contactId;
  final String name;
  final Cents amountCents;
  final bool settled;
}

class TransactionSplit {
  const TransactionSplit({required this.categoryId, required this.amountCents});

  factory TransactionSplit.fromJson(Json json) =>
      TransactionSplit(categoryId: json['category_id'] as String, amountCents: intOf(json['amount_cents']));

  final String categoryId;
  final Cents amountCents;
}

class Tag {
  const Tag({required this.id, required this.name, required this.transactionsCount});

  factory Tag.fromJson(Json json) =>
      Tag(id: json['id'] as String, name: json['name'] as String, transactionsCount: intOf(json['transactions_count']));

  final String id;
  final String name;
  final int transactionsCount;
}

class ContactOption {
  const ContactOption({required this.id, required this.name, required this.archived, required this.balanceCents});

  factory ContactOption.fromJson(Json json) => ContactOption(
    id: json['id'] as String,
    name: json['name'] as String,
    archived: json['archived'] as bool? ?? false,
    balanceCents: intOf(json['balance_cents']),
  );

  final String id;
  final String name;
  final bool archived;
  final Cents balanceCents;
}

class Transaction {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.account,
    required this.kind,
    required this.amountCents,
    required this.date,
    required this.categoryId,
    required this.category,
    required this.payee,
    required this.description,
    required this.notes,
    required this.tags,
    required this.status,
    required this.transferGroupId,
    required this.transferAccountId,
    required this.fromBank,
    required this.bankName,
    required this.uncategorized,
    required this.splits,
    required this.shares,
  });

  factory Transaction.fromJson(Json json) => Transaction(
    id: json['id'] as String,
    accountId: json['account_id'] as String,
    account: AccountRef.fromJson(json['account'] as Json),
    kind: TransactionKind.of(json['kind'] as String?),
    amountCents: intOf(json['amount_cents']),
    date: parseIsoDate(json['date'] as String),
    categoryId: json['category_id'] as String?,
    category: json['category'] is Json ? CategorySummary.fromJson(json['category'] as Json) : null,
    payee: json['payee'] as String?,
    description: json['description'] as String?,
    notes: json['notes'] as String?,
    tags: [for (final tag in json['tags'] as List? ?? const []) tag as String],
    status: TransactionStatus.of(json['status'] as String?),
    transferGroupId: json['transfer_group_id'] as String?,
    transferAccountId: json['transfer_account_id'] as String?,
    fromBank: json['source'] == 'bank',
    bankName: (json['bank'] as Json?)?['aspsp_name'] as String?,
    uncategorized: json['uncategorized'] as bool? ?? false,
    splits: parseList(json['splits'], TransactionSplit.fromJson),
    shares: parseList(json['shares'], TransactionShare.fromJson),
  );

  final String id;
  final String accountId;
  final AccountRef account;
  final TransactionKind kind;
  final Cents amountCents;
  final DateTime date;
  final String? categoryId;
  final CategorySummary? category;
  final String? payee;
  final String? description;
  final String? notes;
  final List<String> tags;
  final TransactionStatus status;
  final String? transferGroupId;
  final String? transferAccountId;
  final bool fromBank;
  final String? bankName;
  final bool uncategorized;
  final List<TransactionSplit> splits;
  final List<TransactionShare> shares;

  int get splitCount => splits.length;

  bool get isSplit => splits.isNotEmpty;

  bool get sharesLocked => shares.any((share) => share.settled);
}

class TransactionTotals {
  const TransactionTotals({required this.count, required this.incomeCents, required this.expenseCents});

  factory TransactionTotals.fromJson(Json json) => TransactionTotals(
    count: intOf(json['count']),
    incomeCents: intOf(json['income_cents']),
    expenseCents: intOf(json['expense_cents']),
  );

  final int count;
  final Cents incomeCents;
  final Cents expenseCents;
}

class TransactionPage {
  const TransactionPage({required this.data, required this.nextCursor, required this.hasMore, required this.totals});

  factory TransactionPage.fromJson(Json json) {
    final meta = json['meta'] as Json;
    return TransactionPage(
      data: parseList(json['data'], Transaction.fromJson),
      nextCursor: meta['next_cursor'] as String?,
      hasMore: meta['has_more'] as bool? ?? false,
      totals: TransactionTotals.fromJson(meta['totals'] as Json),
    );
  }

  final List<Transaction> data;
  final String? nextCursor;
  final bool hasMore;
  final TransactionTotals totals;
}

class UncategorizedSummary {
  const UncategorizedSummary({required this.expenseCents, required this.count});

  static UncategorizedSummary? fromJsonOrNull(Object? json) => json is Json
      ? UncategorizedSummary(expenseCents: intOf(json['expense_cents']), count: intOf(json['count']))
      : null;

  final Cents expenseCents;
  final int count;
}

class BudgetCategory {
  const BudgetCategory({required this.name, required this.parent, required this.icon, required this.sortKey});

  factory BudgetCategory.fromJson(Json json) => BudgetCategory(
    name: json['name'] as String,
    parent: json['parent'] as String?,
    icon: json['icon'] as String?,
    sortKey: intOf(json['sort_key']),
  );

  final String name;
  final String? parent;
  final String? icon;
  final int sortKey;

  String get label => parent == null ? name : '$parent › $name';
}

class BudgetRow {
  const BudgetRow({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.amountCents,
    required this.rollover,
    required this.rolloverInCents,
    required this.availableCents,
    required this.spentCents,
    required this.remainingCents,
    required this.status,
    required this.projectedCents,
    required this.projectedStatus,
  });

  factory BudgetRow.fromJson(Json json) => BudgetRow(
    id: json['id'] as String,
    categoryId: json['category_id'] as String,
    category: BudgetCategory.fromJson(json['category'] as Json),
    amountCents: intOf(json['amount_cents']),
    rollover: json['rollover'] as bool? ?? false,
    rolloverInCents: intOf(json['rollover_in_cents']),
    availableCents: intOf(json['available_cents']),
    spentCents: intOf(json['spent_cents']),
    remainingCents: intOf(json['remaining_cents']),
    status: budgetStatusOf(json['status'] as String?),
    projectedCents: intOf(json['projected_cents']),
    projectedStatus: budgetStatusOf(json['projected_status'] as String?),
  );

  final String id;
  final String categoryId;
  final BudgetCategory category;
  final Cents amountCents;
  final bool rollover;
  final Cents rolloverInCents;
  final Cents availableCents;
  final Cents spentCents;
  final Cents remainingCents;
  final BudgetStatus status;
  final Cents projectedCents;
  final BudgetStatus projectedStatus;
}

class BudgetTotals {
  const BudgetTotals({
    required this.budgetedCents,
    required this.spentCents,
    required this.remainingCents,
    required this.percentBp,
    required this.projectedCents,
  });

  factory BudgetTotals.fromJson(Json json) => BudgetTotals(
    budgetedCents: intOf(json['budgeted_cents']),
    spentCents: intOf(json['spent_cents']),
    remainingCents: intOf(json['remaining_cents']),
    percentBp: intOrNull(json['percent_bp']),
    projectedCents: intOf(json['projected_cents']),
  );

  final Cents budgetedCents;
  final Cents spentCents;
  final Cents remainingCents;
  final BasisPoints? percentBp;
  final Cents projectedCents;
}

class BudgetOverview {
  const BudgetOverview({
    required this.rows,
    required this.period,
    required this.previousPeriod,
    required this.totals,
    required this.uncategorized,
    this.copied,
  });

  factory BudgetOverview.fromJson(Json json) {
    final meta = json['meta'] as Json;
    return BudgetOverview(
      rows: parseList(json['data'], BudgetRow.fromJson),
      period: Period.fromJson(meta['period'] as Json),
      previousPeriod: meta['previous_period'] is Json ? Period.fromJson(meta['previous_period'] as Json) : null,
      totals: BudgetTotals.fromJson(meta['totals'] as Json),
      uncategorized: UncategorizedSummary.fromJsonOrNull(meta['uncategorized']),
      copied: intOrNull(meta['copied']),
    );
  }

  final List<BudgetRow> rows;
  final Period period;
  final Period? previousPeriod;
  final BudgetTotals totals;
  final UncategorizedSummary? uncategorized;
  final int? copied;
}

class DashboardCategoryGroup {
  const DashboardCategoryGroup({required this.name, required this.color, required this.amountCents});

  factory DashboardCategoryGroup.fromJson(Json json) => DashboardCategoryGroup(
    name: json['name'] as String,
    color: json['color'] as String?,
    amountCents: intOf(json['amount_cents']),
  );

  final String name;
  final String? color;
  final Cents amountCents;
}

class DashboardHistoryPoint {
  const DashboardHistoryPoint({
    required this.label,
    required this.incomeCents,
    required this.expenseCents,
    required this.netWorthCents,
  });

  factory DashboardHistoryPoint.fromJson(Json json) => DashboardHistoryPoint(
    label: json['label'] as String,
    incomeCents: intOf(json['income_cents']),
    expenseCents: intOf(json['expense_cents']),
    netWorthCents: intOf(json['net_worth_cents']),
  );

  final String label;
  final Cents incomeCents;
  final Cents expenseCents;
  final Cents netWorthCents;
}

class UpcomingCharge {
  const UpcomingCharge({
    required this.ruleId,
    required this.name,
    required this.date,
    required this.amountCents,
    this.category,
  });

  factory UpcomingCharge.fromJson(Json json) => UpcomingCharge(
    ruleId: json['rule_id'] as String,
    name: json['name'] as String,
    date: parseIsoDate(json['date'] as String),
    amountCents: intOf(json['amount_cents']),
    category: json['category'] is Json ? CategorySummary.fromJson(json['category'] as Json) : null,
  );

  final String ruleId;
  final String name;
  final DateTime date;
  final Cents amountCents;
  final CategorySummary? category;
}

class Dashboard {
  const Dashboard({
    required this.period,
    required this.previousPeriod,
    required this.incomeCents,
    required this.expenseCents,
    required this.savingsCents,
    required this.savingsRateBp,
    required this.netWorthCents,
    required this.netWorthDeltaCents,
    required this.incomeDeltaBp,
    required this.expenseDeltaBp,
    required this.byCategory,
    required this.history,
    required this.topBudgets,
    required this.upcoming,
    required this.recentTransactions,
    required this.uncategorized,
  });

  factory Dashboard.fromJson(Json json) {
    final deltas = json['deltas_bp'] as Json?;
    return Dashboard(
      period: Period.fromJson(json['period'] as Json),
      previousPeriod: json['previous_period'] is Json ? Period.fromJson(json['previous_period'] as Json) : null,
      incomeCents: intOf(json['income_cents']),
      expenseCents: intOf(json['expense_cents']),
      savingsCents: intOf(json['savings_cents']),
      savingsRateBp: intOrNull(json['savings_rate_bp']),
      netWorthCents: intOf(json['net_worth_cents']),
      netWorthDeltaCents: intOrNull(json['net_worth_delta_cents']),
      incomeDeltaBp: intOrNull(deltas?['income']),
      expenseDeltaBp: intOrNull(deltas?['expense']),
      byCategory: parseList(json['by_category'], DashboardCategoryGroup.fromJson),
      history: parseList(json['history'], DashboardHistoryPoint.fromJson),
      topBudgets: parseList((json['budgets'] as Json?)?['top'], BudgetRow.fromJson),
      upcoming: parseList(json['upcoming'], UpcomingCharge.fromJson),
      recentTransactions: parseList(json['recent_transactions'], Transaction.fromJson),
      uncategorized: UncategorizedSummary.fromJsonOrNull(json['uncategorized']),
    );
  }

  final Period period;
  final Period? previousPeriod;
  final Cents incomeCents;
  final Cents expenseCents;
  final Cents savingsCents;
  final BasisPoints? savingsRateBp;
  final Cents netWorthCents;
  final Cents? netWorthDeltaCents;
  final BasisPoints? incomeDeltaBp;
  final BasisPoints? expenseDeltaBp;
  final List<DashboardCategoryGroup> byCategory;
  final List<DashboardHistoryPoint> history;
  final List<BudgetRow> topBudgets;
  final List<UpcomingCharge> upcoming;
  final List<Transaction> recentTransactions;
  final UncategorizedSummary? uncategorized;
}

class FinanceSummary {
  const FinanceSummary({
    required this.period,
    required this.spentCents,
    required this.netWorthCents,
    required this.budget,
  });

  factory FinanceSummary.fromJson(Json json) => FinanceSummary(
    period: Period.fromJson(json['period'] as Json),
    spentCents: intOf(json['spent_cents']),
    netWorthCents: intOf(json['net_worth_cents']),
    budget: BudgetTotals.fromJson(json['budget'] as Json),
  );

  final Period period;
  final Cents spentCents;
  final Cents netWorthCents;
  final BudgetTotals budget;
}

class FinanceSettings {
  const FinanceSettings({
    required this.defaultAccountId,
    required this.lastUsedAccountId,
    required this.budgetWarningThreshold,
    required this.calendarPeriods,
  });

  factory FinanceSettings.fromJson(Json json) => FinanceSettings(
    defaultAccountId: json['default_account_id'] as String?,
    lastUsedAccountId: json['last_used_account_id'] as String?,
    budgetWarningThreshold: intOrNull(json['budget_warning_threshold']) ?? 80,
    calendarPeriods: json['period_mode'] == 'calendar',
  );

  final String? defaultAccountId;
  final String? lastUsedAccountId;
  final int budgetWarningThreshold;
  final bool calendarPeriods;

  String? get preferredAccountId => defaultAccountId ?? lastUsedAccountId;

  double get warnAt => budgetWarningThreshold / 100;
}

class PayeeSuggestion {
  const PayeeSuggestion({required this.payee, required this.category});

  factory PayeeSuggestion.fromJson(Json json) => PayeeSuggestion(
    payee: json['payee'] as String,
    category: json['category'] is Json ? CategorySummary.fromJson(json['category'] as Json) : null,
  );

  final String payee;
  final CategorySummary? category;
}

class Saved<T> {
  const Saved(this.value, {required this.periodsChanged});

  final T value;
  final bool periodsChanged;
}
