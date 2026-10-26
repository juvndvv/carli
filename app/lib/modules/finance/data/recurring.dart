import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import 'finance_changes.dart';
import 'finance_providers.dart';
import 'json.dart';
import 'models.dart';

enum RecurrenceFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceFrequency(this.api);

  final String api;

  static RecurrenceFrequency of(String? value) =>
      values.firstWhere((frequency) => frequency.api == value, orElse: () => monthly);
}

enum RecurringMode {
  auto('auto', 'Automático'),
  confirm('confirm', 'Con confirmación');

  const RecurringMode(this.api, this.label);

  final String api;
  final String label;

  static RecurringMode of(String? value) => value == 'confirm' ? confirm : auto;
}

enum FrequencyPreset {
  weekly('Semanal'),
  monthly('Mensual'),
  quarterly('Trimestral'),
  yearly('Anual'),
  everyDays('Cada N días'),
  everyMonths('Cada N meses');

  const FrequencyPreset(this.label);

  final String label;

  bool get custom => this == everyDays || this == everyMonths;
}

enum RecurringTab {
  all('Todos'),
  subscriptions('Suscripciones'),
  pending('Pendientes de confirmar'),
  cancelled('Canceladas');

  const RecurringTab(this.label);

  final String label;
}

class RecurringPendingTransaction {
  const RecurringPendingTransaction({required this.id, required this.date, required this.amountCents});

  factory RecurringPendingTransaction.fromJson(Json json) => RecurringPendingTransaction(
    id: json['id'] as String,
    date: parseIsoDate(json['date'] as String),
    amountCents: intOf(json['amount_cents']),
  );

  final String id;
  final DateTime date;
  final Cents amountCents;
}

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.name,
    required this.accountId,
    required this.account,
    required this.categoryId,
    required this.category,
    required this.kind,
    required this.amountCents,
    required this.payee,
    required this.description,
    required this.frequency,
    required this.interval,
    required this.dayOfMonth,
    required this.startDate,
    required this.endDate,
    required this.nextOccurrence,
    required this.mode,
    required this.remindDaysBefore,
    required this.isSubscription,
    required this.cancelled,
    required this.active,
    required this.monthlyCostCents,
    required this.yearlyCostCents,
    required this.pendingTransaction,
    required this.debtId,
  });

  factory RecurringRule.fromJson(Json json) => RecurringRule(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    accountId: json['account_id'] as String,
    account: AccountRef.fromJson(json['account'] as Json),
    categoryId: json['category_id'] as String?,
    category: json['category'] is Json ? CategorySummary.fromJson(json['category'] as Json) : null,
    kind: json['kind'] == 'income' ? TransactionKind.income : TransactionKind.expense,
    amountCents: intOf(json['amount_cents']),
    payee: json['payee'] as String?,
    description: json['description'] as String?,
    frequency: RecurrenceFrequency.of(json['frequency'] as String?),
    interval: intOrNull(json['interval']) ?? 1,
    dayOfMonth: intOrNull(json['day_of_month']),
    startDate: parseIsoDate(json['start_date'] as String),
    endDate: parseIsoDateOrNull(json['end_date']),
    nextOccurrence: parseIsoDateOrNull(json['next_occurrence']),
    mode: RecurringMode.of(json['mode'] as String?),
    remindDaysBefore: intOf(json['remind_days_before']),
    isSubscription: json['is_subscription'] as bool? ?? false,
    cancelled: json['cancelled'] as bool? ?? false,
    active: json['active'] as bool? ?? false,
    monthlyCostCents: intOf(json['monthly_cost_cents']),
    yearlyCostCents: intOf(json['yearly_cost_cents']),
    pendingTransaction: json['pending_transaction'] is Json
        ? RecurringPendingTransaction.fromJson(json['pending_transaction'] as Json)
        : null,
    debtId: json['debt_id'] as String?,
  );

  final String id;
  final String name;
  final String accountId;
  final AccountRef account;
  final String? categoryId;
  final CategorySummary? category;
  final TransactionKind kind;
  final Cents amountCents;
  final String? payee;
  final String? description;
  final RecurrenceFrequency frequency;
  final int interval;
  final int? dayOfMonth;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextOccurrence;
  final RecurringMode mode;
  final int remindDaysBefore;
  final bool isSubscription;
  final bool cancelled;
  final bool active;
  final Cents monthlyCostCents;
  final Cents yearlyCostCents;
  final RecurringPendingTransaction? pendingTransaction;
  final String? debtId;
}

class RecurringRulesMeta {
  const RecurringRulesMeta({
    required this.activeCount,
    required this.monthlyTotalCents,
    required this.subscriptionsCount,
    required this.subscriptionsMonthlyCents,
    required this.subscriptionsYearlyCents,
  });

  factory RecurringRulesMeta.fromJson(Json? json) {
    final subscriptions = json?['subscriptions'] as Json?;
    return RecurringRulesMeta(
      activeCount: intOf(json?['active_count']),
      monthlyTotalCents: intOf(json?['monthly_total_cents']),
      subscriptionsCount: intOf(subscriptions?['count']),
      subscriptionsMonthlyCents: intOf(subscriptions?['monthly_cents']),
      subscriptionsYearlyCents: intOf(subscriptions?['yearly_cents']),
    );
  }

  final int activeCount;
  final Cents monthlyTotalCents;
  final int subscriptionsCount;
  final Cents subscriptionsMonthlyCents;
  final Cents subscriptionsYearlyCents;
}

class RecurringRules {
  const RecurringRules({required this.rules, required this.meta});

  final List<RecurringRule> rules;
  final RecurringRulesMeta meta;

  int get pendingCount => rules.where((rule) => rule.pendingTransaction != null).length;

  List<RecurringRule> get subscriptions => [
    for (final rule in rules)
      if (rule.isSubscription && !rule.cancelled) rule,
  ];
}

class ConfirmRecurringResult {
  const ConfirmRecurringResult({
    required this.transactionId,
    required this.transactionAmountCents,
    required this.transactionDate,
    required this.rule,
    required this.priceChanged,
    required this.previousAmountCents,
  });

  factory ConfirmRecurringResult.fromJson(Json json) {
    final transaction = json['transaction'] as Json;
    return ConfirmRecurringResult(
      transactionId: transaction['id'] as String,
      transactionAmountCents: intOf(transaction['amount_cents']),
      transactionDate: parseIsoDate(transaction['date'] as String),
      rule: RecurringRule.fromJson(json['rule'] as Json),
      priceChanged: json['price_changed'] as bool? ?? false,
      previousAmountCents: intOf(json['previous_amount_cents']),
    );
  }

  final String transactionId;
  final Cents transactionAmountCents;
  final DateTime transactionDate;
  final RecurringRule rule;
  final bool priceChanged;
  final Cents previousAmountCents;
}

final recurringApiProvider = Provider<RecurringApi>((ref) => RecurringApi(ref.watch(dioProvider)));

class RecurringApi {
  RecurringApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance/recurring-rules';

  Future<RecurringRules> list() async {
    final response = await _dio.get<Json>(_base, queryParameters: {'include_cancelled': '1'});
    final body = response.data!;
    return RecurringRules(
      rules: parseList(body['data'], RecurringRule.fromJson),
      meta: RecurringRulesMeta.fromJson(body['meta'] as Json?),
    );
  }

  Future<RecurringRule> get(String id) async {
    final response = await _dio.get<Json>('$_base/$id');
    return RecurringRule.fromJson(response.data!['data'] as Json);
  }

  Future<RecurringRule> create(Json payload) async {
    final response = await _dio.post<Json>(_base, data: payload);
    return RecurringRule.fromJson(response.data!['data'] as Json);
  }

  Future<RecurringRule> update(String id, Json patch) async {
    final response = await _dio.patch<Json>('$_base/$id', data: patch);
    return RecurringRule.fromJson(response.data!['data'] as Json);
  }

  Future<void> delete(String id) async {
    await _dio.delete<Object?>('$_base/$id');
  }

  Future<ConfirmRecurringResult> confirm(String id, Json payload) async {
    final response = await _dio.post<Json>('$_base/$id/confirm', data: payload);
    return ConfirmRecurringResult.fromJson(response.data!['data'] as Json);
  }

  Future<int> reminderDays() async {
    final response = await _dio.get<Json>('/v1/finance/settings');
    return intOf((response.data!['data'] as Json)['remind_days_before']);
  }
}

final recurringRulesProvider = FutureProvider<RecurringRules>((ref) async {
  ref.watchFinance(const [
    FinanceScope.transactions,
    FinanceScope.accounts,
    FinanceScope.categories,
    FinanceScope.recurring,
  ]);
  return ref.watch(recurringApiProvider).list();
});

final recurringReminderDaysProvider = FutureProvider<int?>((ref) async {
  ref.watchFinance(const [FinanceScope.settings]);
  try {
    return await ref.watch(recurringApiProvider).reminderDays();
  } on Object {
    return null;
  }
});

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(
    ref.watch(recurringApiProvider),
    ref.read(financeChangesProvider.notifier),
    () => ref.invalidate(recurringRulesProvider),
  ),
);

class RecurringRepository {
  RecurringRepository(this._api, this._changes, this._reload);

  final RecurringApi _api;
  final FinanceChanges _changes;
  final void Function() _reload;

  Future<RecurringRule> get(String id) => _api.get(id);

  Future<RecurringRule> create(Json payload) async {
    final rule = await _api.create(payload);
    _reload();
    return rule;
  }

  Future<RecurringRule> update(String id, Json patch) async {
    final rule = await _api.update(id, patch);
    _reload();
    return rule;
  }

  Future<RecurringRule> setCancelled(String id, bool cancelled) => update(id, {'cancelled': cancelled});

  Future<void> remove(String id) async {
    await _api.delete(id);
    _reload();
  }

  Future<ConfirmRecurringResult> confirm(String id, Json payload) async {
    final result = await _api.confirm(id, payload);
    _changes.notifyTransactions();
    _reload();
    return result;
  }
}

({RecurrenceFrequency frequency, int interval}) presetToSchedule(FrequencyPreset preset, int customInterval) {
  final interval = customInterval < 1 ? 1 : customInterval;
  return switch (preset) {
    FrequencyPreset.weekly => (frequency: RecurrenceFrequency.weekly, interval: 1),
    FrequencyPreset.monthly => (frequency: RecurrenceFrequency.monthly, interval: 1),
    FrequencyPreset.quarterly => (frequency: RecurrenceFrequency.monthly, interval: 3),
    FrequencyPreset.yearly => (frequency: RecurrenceFrequency.yearly, interval: 1),
    FrequencyPreset.everyDays => (frequency: RecurrenceFrequency.daily, interval: interval),
    FrequencyPreset.everyMonths => (frequency: RecurrenceFrequency.monthly, interval: interval),
  };
}

FrequencyPreset scheduleToPreset(RecurrenceFrequency frequency, int interval) => switch (frequency) {
  RecurrenceFrequency.daily => FrequencyPreset.everyDays,
  RecurrenceFrequency.weekly => FrequencyPreset.weekly,
  RecurrenceFrequency.yearly => FrequencyPreset.yearly,
  RecurrenceFrequency.monthly when interval == 1 => FrequencyPreset.monthly,
  RecurrenceFrequency.monthly when interval == 3 => FrequencyPreset.quarterly,
  RecurrenceFrequency.monthly => FrequencyPreset.everyMonths,
};

String frequencyLabel({
  required RecurrenceFrequency frequency,
  required int interval,
  required DateTime startDate,
  int? dayOfMonth,
}) {
  final every = interval < 1 ? 1 : interval;
  final day = dayOfMonth ?? startDate.day;
  switch (frequency) {
    case RecurrenceFrequency.daily:
      return every == 1 ? 'Diario' : 'Cada $every días';
    case RecurrenceFrequency.weekly:
      final weekday = weekdaysLong[startDate.weekday - 1];
      return every == 1 ? 'Semanal · $weekday' : 'Cada $every semanas · $weekday';
    case RecurrenceFrequency.monthly:
      final base = switch (every) {
        1 => 'Mensual',
        3 => 'Trimestral',
        6 => 'Semestral',
        _ => 'Cada $every meses',
      };
      return '$base · día $day';
    case RecurrenceFrequency.yearly:
      final base = every == 1 ? 'Anual' : 'Cada $every años';
      return '$base · ${formatShortDate(startDate)}';
  }
}

String ruleFrequencyLabel(RecurringRule rule) => frequencyLabel(
  frequency: rule.frequency,
  interval: rule.interval,
  startDate: rule.startDate,
  dayOfMonth: rule.dayOfMonth,
);

List<RecurringRule> filterRecurringRules(List<RecurringRule> rules, RecurringTab tab) => [
  for (final rule in rules)
    if (switch (tab) {
      RecurringTab.all => !rule.cancelled,
      RecurringTab.subscriptions => rule.isSubscription && !rule.cancelled,
      RecurringTab.pending => rule.pendingTransaction != null,
      RecurringTab.cancelled => rule.cancelled,
    })
      rule,
];

List<RecurringRule> upcomingCharges(List<RecurringRule> rules, DateTime today, int days) {
  final from = dateOnly(today);
  final limit = from.add(Duration(days: days));
  return [
    for (final rule in rules)
      if (rule.nextOccurrence case final next? when rule.active && !next.isBefore(from) && !next.isAfter(limit)) rule,
  ]..sort((left, right) => left.nextOccurrence!.compareTo(right.nextOccurrence!));
}

String reminderLabel(int days) => switch (days) {
  0 => 'El mismo día',
  1 => '1 día antes',
  _ => '$days días antes',
};

String recurringSubtitle(RecurringRule rule) {
  final parts = [ruleFrequencyLabel(rule)];
  if (rule.pendingTransaction case final pending?) {
    parts.add('pendiente del ${formatShortDate(pending.date)}');
  } else if (rule.nextOccurrence case final next? when !rule.cancelled) {
    parts.add('próximo ${formatShortDate(next)}');
  } else if (rule.nextOccurrence == null && !rule.cancelled) {
    parts.add('finalizado');
  }
  return parts.join(' · ');
}

String upcomingChargeLabel(RecurringRule rule, {DateTime? now}) {
  final date = rule.nextOccurrence!;
  final reference = today(now);
  final days = daysBetween(reference, date);
  final relative = formatRelativeDay(date, now: reference, style: RelativeDateStyle.title);
  return days <= 1 ? '$relative · ${rule.account.name}' : '$relative · en $days días · ${rule.account.name}';
}

String recurringIconName(RecurringRule rule) =>
    rule.category?.icon ?? (rule.kind == TransactionKind.income ? 'briefcase' : 'repeat');

String subscriptionsCountLabel(int count) => count == 1 ? '1 activa' : '$count activas';

DateTime addMonths(DateTime value, int months) {
  final target = DateTime(value.year, value.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, value.day > lastDay ? lastDay : value.day);
}

String accountTypeIcon(AccountType type) => switch (type) {
  AccountType.checking => 'landmark',
  AccountType.savings => 'piggy-bank',
  AccountType.creditCard => 'credit-card',
  AccountType.cash => 'banknote',
};

class RecurringOption {
  const RecurringOption({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final String icon;
}

List<RecurringOption> recurringAccountOptions(List<Account> accounts) => [
  for (final account in accounts)
    if (!account.archived)
      RecurringOption(id: account.id, label: account.name, icon: account.icon ?? accountTypeIcon(account.type)),
];

String _sortable(String text) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n~'};
  return text.toLowerCase().split('').map((char) => accents[char] ?? char).join();
}

List<RecurringOption> recurringCategoryOptions(CategoryIndex categories, CategoryKind kind) => [
  for (final entry in categories.selectable(kind))
    RecurringOption(
      id: entry.category.id,
      label: entry.parent == null ? entry.category.name : '${entry.parent!.name} · ${entry.category.name}',
      icon: entry.category.icon ?? entry.parent?.icon ?? 'tag',
    ),
]..sort((left, right) => _sortable(left.label).compareTo(_sortable(right.label)));

String? preferredAccountId(List<Account> accounts, {AccountType type = AccountType.checking}) {
  final active = [
    for (final account in accounts)
      if (!account.archived) account,
  ];
  return (active.where((account) => account.type == type).firstOrNull ?? active.firstOrNull)?.id;
}

class RecurringDraft {
  RecurringDraft({
    required this.kind,
    required this.amount,
    required this.payee,
    required this.accountId,
    required this.categoryId,
    required this.preset,
    required this.interval,
    required this.startDate,
    required this.hasEnd,
    required this.endDate,
    required this.mode,
    required this.remindDaysBefore,
    required this.isSubscription,
  });

  factory RecurringDraft.from(RecurringRule? rule, {bool isSubscription = false, DateTime? now}) => RecurringDraft(
    kind: rule?.kind ?? TransactionKind.expense,
    amount: rule?.amountCents.abs(),
    payee: rule?.payee ?? rule?.name ?? '',
    accountId: rule?.accountId,
    categoryId: rule?.categoryId,
    preset: rule == null ? FrequencyPreset.monthly : scheduleToPreset(rule.frequency, rule.interval),
    interval: rule != null && rule.interval > 1 ? rule.interval : 2,
    startDate: rule?.startDate ?? today(now),
    hasEnd: rule?.endDate != null,
    endDate: rule?.endDate,
    mode: rule?.mode ?? RecurringMode.auto,
    remindDaysBefore: rule?.remindDaysBefore ?? 2,
    isSubscription: rule?.isSubscription ?? isSubscription,
  );

  TransactionKind kind;
  Cents? amount;
  String payee;
  String? accountId;
  String? categoryId;
  FrequencyPreset preset;
  int? interval;
  DateTime startDate;
  bool hasEnd;
  DateTime? endDate;
  RecurringMode mode;
  int? remindDaysBefore;
  bool isSubscription;

  bool get amountInvalid => amount == null || amount! < 1;

  bool get payeeInvalid => payee.trim().isEmpty || payee.trim().length > 160;

  bool get accountInvalid => accountId == null;

  bool get intervalInvalid => preset.custom && (interval == null || interval! < 1 || interval! > 365);

  bool get remindInvalid => remindDaysBefore == null || remindDaysBefore! < 0 || remindDaysBefore! > 30;

  bool get endBeforeStart => hasEnd && endDate != null && endDate!.isBefore(startDate);

  bool get valid =>
      !amountInvalid && !payeeInvalid && !accountInvalid && !intervalInvalid && !remindInvalid && !endBeforeStart;

  void setHasEnd(bool value) {
    hasEnd = value;
    if (value && endDate == null) endDate = addMonths(startDate, 12);
  }

  Json toPayload() {
    final magnitude = (amount ?? 0).abs();
    final schedule = presetToSchedule(preset, interval ?? 1);
    return {
      'kind': kind.api,
      'amount_cents': kind == TransactionKind.expense ? -magnitude : magnitude,
      'payee': payee.trim(),
      'account_id': accountId,
      'category_id': categoryId,
      'frequency': schedule.frequency.api,
      'interval': schedule.interval,
      'start_date': isoDate(startDate),
      'end_date': hasEnd && endDate != null ? isoDate(endDate!) : null,
      'mode': mode.api,
      'remind_days_before': remindDaysBefore,
      'is_subscription': isSubscription,
    };
  }
}

enum PriceDirection { up, down }

class PriceChange {
  const PriceChange({required this.direction, required this.differenceCents, required this.percent});

  final PriceDirection direction;
  final Cents differenceCents;
  final int percent;

  String get title =>
      '${direction == PriceDirection.up ? 'Sube' : 'Baja'} ${formatMoney(differenceCents)} ($percent %) respecto a lo previsto';

  @override
  bool operator ==(Object other) =>
      other is PriceChange &&
      other.direction == direction &&
      other.differenceCents == differenceCents &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(direction, differenceCents, percent);
}

PriceChange? detectPriceChange(Cents expectedCents, Cents? actualCents) {
  final expected = expectedCents.abs();
  if (actualCents == null || actualCents <= 0 || actualCents == expected) return null;
  final difference = actualCents - expected;
  return PriceChange(
    direction: difference > 0 ? PriceDirection.up : PriceDirection.down,
    differenceCents: difference.abs(),
    percent: expected == 0 ? 0 : (difference.abs() / expected * 100).round(),
  );
}

DateTime occurrenceDateOf(RecurringRule rule, {DateTime? now}) =>
    rule.pendingTransaction?.date ?? rule.nextOccurrence ?? today(now);

Cents expectedAmountOf(RecurringRule rule) => rule.pendingTransaction?.amountCents ?? rule.amountCents;

Json confirmOccurrencePayload({
  required RecurringRule rule,
  required Cents amount,
  required DateTime date,
  required bool updateRuleAmount,
}) => {
  'amount_cents': amount,
  'date': isoDate(date),
  'update_rule_amount': detectPriceChange(rule.amountCents, amount) != null && updateRuleAmount,
};

String confirmedToast(RecurringRule rule, ConfirmRecurringResult result, {required bool updateRuleAmount}) {
  final amount = formatMoney(result.transactionAmountCents, display: MoneyDisplay.signed);
  final suffix = result.priceChanged && updateRuleAmount ? ' · importe actualizado' : '';
  return '${rule.name} confirmado: $amount$suffix';
}
