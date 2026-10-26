import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import 'finance_api.dart';
import 'finance_changes.dart';
import 'json.dart';
import 'models.dart';

const accountHistoryDays = 90;
const accountHistoryMaxPages = 5;
const accountHistoryPageSize = 200;
const accountIconChoices = ['landmark', 'piggy-bank', 'credit-card', 'banknote', 'wallet', 'coins', 'euro', 'building'];
const accountColorChoices = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8'];

String accountTypeApi(AccountType type) => switch (type) {
  AccountType.checking => 'checking',
  AccountType.savings => 'savings',
  AccountType.creditCard => 'credit_card',
  AccountType.cash => 'cash',
};

String accountTypeLabel(AccountType type) => switch (type) {
  AccountType.checking => 'Corriente',
  AccountType.savings => 'Ahorro',
  AccountType.creditCard => 'Tarjeta de crédito',
  AccountType.cash => 'Efectivo',
};

String accountTypeIcon(AccountType type) => switch (type) {
  AccountType.checking => 'landmark',
  AccountType.savings => 'piggy-bank',
  AccountType.creditCard => 'credit-card',
  AccountType.cash => 'banknote',
};

class BankLinkDetails {
  const BankLinkDetails({
    required this.connectionId,
    required this.aspspName,
    required this.status,
    required this.lastSyncedAt,
    required this.balanceCents,
    required this.balanceAt,
    required this.differenceCents,
  });

  factory BankLinkDetails.fromJson(Json json) => BankLinkDetails(
    connectionId: json['connection_id'] as String? ?? '',
    aspspName: json['aspsp_name'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    lastSyncedAt: _instantOrNull(json['last_synced_at']),
    balanceCents: intOrNull(json['balance_cents']),
    balanceAt: _instantOrNull(json['balance_at']),
    differenceCents: intOrNull(json['difference_cents']),
  );

  final String connectionId;
  final String aspspName;
  final String status;
  final DateTime? lastSyncedAt;
  final Cents? balanceCents;
  final DateTime? balanceAt;
  final Cents? differenceCents;
}

DateTime? _instantOrNull(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

class AccountDetails {
  const AccountDetails({
    required this.id,
    required this.name,
    required this.type,
    this.initialBalanceCents = 0,
    this.initialBalanceDate,
    this.balanceCents = 0,
    this.clearedBalanceCents = 0,
    this.pendingCents = 0,
    this.creditLimitCents,
    this.statementDay,
    this.paymentDay,
    this.usedCreditCents,
    this.availableCreditCents,
    this.color,
    this.icon,
    this.includeInNetWorth = true,
    this.archived = false,
    this.bank,
  });

  factory AccountDetails.fromJson(Json json) {
    final balance = intOf(json['balance_cents']);
    return AccountDetails(
      id: json['id'] as String,
      name: json['name'] as String,
      type: accountTypeOf(json['type'] as String?),
      initialBalanceCents: intOf(json['initial_balance_cents']),
      initialBalanceDate: parseIsoDateOrNull(json['initial_balance_date']),
      balanceCents: balance,
      clearedBalanceCents: intOrNull(json['cleared_balance_cents']) ?? balance,
      pendingCents: intOf(json['pending_cents']),
      creditLimitCents: intOrNull(json['credit_limit_cents']),
      statementDay: intOrNull(json['statement_day']),
      paymentDay: intOrNull(json['payment_day']),
      usedCreditCents: intOrNull(json['used_credit_cents']),
      availableCreditCents: intOrNull(json['available_credit_cents']),
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      includeInNetWorth: json['include_in_net_worth'] as bool? ?? true,
      archived: json['archived'] as bool? ?? false,
      bank: json['bank'] is Json ? BankLinkDetails.fromJson(json['bank'] as Json) : null,
    );
  }

  final String id;
  final String name;
  final AccountType type;
  final Cents initialBalanceCents;
  final DateTime? initialBalanceDate;
  final Cents balanceCents;
  final Cents clearedBalanceCents;
  final Cents pendingCents;
  final Cents? creditLimitCents;
  final int? statementDay;
  final int? paymentDay;
  final Cents? usedCreditCents;
  final Cents? availableCreditCents;
  final String? color;
  final String? icon;
  final bool includeInNetWorth;
  final bool archived;
  final BankLinkDetails? bank;

  bool get isCreditCard => type == AccountType.creditCard;

  String get iconName => icon ?? accountTypeIcon(type);

  String get typeLabel => accountTypeLabel(type);
}

class AccountsOverview {
  const AccountsOverview({required this.all, required this.netWorthCents});

  final List<AccountDetails> all;
  final Cents? netWorthCents;

  List<AccountDetails> get active => [
    for (final account in all)
      if (!account.archived) account,
  ];

  List<AccountDetails> get archived => [
    for (final account in all)
      if (account.archived) account,
  ];

  AccountDetails? find(String id) => all.where((account) => account.id == id).firstOrNull;
}

class ReconcileResult {
  const ReconcileResult({
    required this.account,
    required this.adjustment,
    required this.differenceCents,
    required this.balanceCents,
  });

  factory ReconcileResult.fromJson(Json json) => ReconcileResult(
    account: AccountDetails.fromJson(json['account'] as Json),
    adjustment: json['adjustment'] is Json ? Transaction.fromJson(json['adjustment'] as Json) : null,
    differenceCents: intOf(json['difference_cents']),
    balanceCents: intOf(json['balance_cents']),
  );

  final AccountDetails account;
  final Transaction? adjustment;
  final Cents differenceCents;
  final Cents balanceCents;
}

class AccountInput {
  const AccountInput({
    required this.name,
    required this.type,
    required this.initialBalanceCents,
    required this.initialBalanceDate,
    required this.creditLimitCents,
    required this.statementDay,
    required this.paymentDay,
    required this.icon,
    required this.color,
    required this.includeInNetWorth,
  });

  final String name;
  final AccountType type;
  final Cents initialBalanceCents;
  final DateTime? initialBalanceDate;
  final Cents? creditLimitCents;
  final int? statementDay;
  final int? paymentDay;
  final String? icon;
  final String? color;
  final bool includeInNetWorth;

  Json toJson() {
    final card = type == AccountType.creditCard;
    return {
      'name': name.trim(),
      'type': accountTypeApi(type),
      'initial_balance_cents': initialBalanceCents,
      'initial_balance_date': initialBalanceDate == null ? null : isoDate(initialBalanceDate!),
      'credit_limit_cents': card ? creditLimitCents : null,
      'statement_day': card ? statementDay : null,
      'payment_day': card ? paymentDay : null,
      'icon': icon,
      'color': color,
      'include_in_net_worth': includeInNetWorth,
    };
  }
}

class BalancePoint {
  const BalancePoint(this.date, this.balanceCents);

  final DateTime date;
  final Cents balanceCents;
}

List<BalancePoint> balanceHistory(Cents currentBalance, List<Transaction> transactions, DateTime today, int days) {
  final byDate = <DateTime, Cents>{};
  for (final transaction in transactions) {
    final day = dateOnly(transaction.date);
    byDate[day] = (byDate[day] ?? 0) + transaction.amountCents;
  }
  final reference = dateOnly(today);
  final future = byDate.entries
      .where((entry) => entry.key.isAfter(reference))
      .fold<int>(0, (sum, entry) => sum + entry.value);
  var balance = currentBalance - future;
  final points = <BalancePoint>[];
  for (var offset = 0; offset < days; offset++) {
    final date = DateTime(reference.year, reference.month, reference.day - offset);
    points.add(BalancePoint(date, balance));
    balance -= byDate[date] ?? 0;
  }
  return points.reversed.toList();
}

String? cardSchedule(AccountDetails account) {
  final parts = [
    if (account.statementDay case final day?) 'Corte día $day',
    if (account.paymentDay case final day?) 'se carga el día $day',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String accountsSummaryLabel(List<AccountDetails> active) {
  final label = active.length == 1 ? '1 cuenta' : '${active.length} cuentas';
  return active.any((account) => account.isCreditCard) ? '$label · las tarjetas de crédito restan' : label;
}

String archivedAccountsLabel(int count) => count == 1 ? '1 cuenta archivada' : '$count cuentas archivadas';

Cents reconcileStartingBalance(AccountDetails account) => account.bank?.balanceCents ?? account.clearedBalanceCents;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String formatDateTime(DateTime instant, {DateTime? now}) {
  final local = instant.toLocal();
  final day = dateOnly(local);
  final reference = today(now);
  final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  if (day == reference) return 'hoy a las $time';
  if (daysBetween(day, reference) == 1) return 'ayer a las $time';
  return '${formatShortDate(day, withYear: day.year != reference.year)}, $time';
}

class BankBalanceSummary {
  const BankBalanceSummary({
    required this.bank,
    required this.balance,
    required this.difference,
    required this.matches,
    required this.updated,
  });

  final String bank;
  final String? balance;
  final String? difference;
  final bool matches;
  final String? updated;
}

BankBalanceSummary? bankBalanceSummary(BankLinkDetails? link, {DateTime? now}) {
  if (link == null) return null;
  final difference = link.differenceCents;
  return BankBalanceSummary(
    bank: link.aspspName,
    balance: link.balanceCents == null ? null : formatMoney(link.balanceCents),
    difference: difference == null || difference == 0 ? null : formatMoney(difference, display: MoneyDisplay.signed),
    matches: difference == 0,
    updated: link.balanceAt == null ? null : formatDateTime(link.balanceAt!, now: now),
  );
}

final accountsAdminApiProvider = Provider<AccountsAdminApi>((ref) => AccountsAdminApi(ref.watch(dioProvider)));

class AccountsAdminApi {
  AccountsAdminApi(this._dio);

  final Dio _dio;

  static const _base = '/v1/finance/accounts';

  Future<AccountsOverview> list() async {
    final response = await _dio.get<Json>(_base, queryParameters: {'include_archived': '1'});
    final body = response.data!;
    return AccountsOverview(
      all: parseList(body['data'], AccountDetails.fromJson),
      netWorthCents: intOrNull((body['meta'] as Json?)?['net_worth_cents']),
    );
  }

  Future<AccountDetails> get(String id) async =>
      AccountDetails.fromJson((await _dio.get<Json>('$_base/$id')).data!['data'] as Json);

  Future<AccountDetails> create(Json input) async =>
      AccountDetails.fromJson((await _dio.post<Json>(_base, data: input)).data!['data'] as Json);

  Future<AccountDetails> update(String id, Json input) async =>
      AccountDetails.fromJson((await _dio.patch<Json>('$_base/$id', data: input)).data!['data'] as Json);

  Future<void> delete(String id) => _dio.delete<Object?>('$_base/$id');

  Future<ReconcileResult> reconcile(String id, Cents actualBalanceCents, DateTime? date) async {
    final response = await _dio.post<Json>(
      '$_base/$id/reconcile',
      data: {'actual_balance_cents': actualBalanceCents, if (date != null) 'date': isoDate(date)},
    );
    return ReconcileResult.fromJson(response.data!['data'] as Json);
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(accountsAdminApiProvider), ref.read(financeChangesProvider.notifier)),
);

class AccountsRepository {
  AccountsRepository(this._api, this._changes);

  final AccountsAdminApi _api;
  final FinanceChanges _changes;

  Future<AccountDetails> create(AccountInput input) async {
    final account = await _api.create(input.toJson());
    _changes.notify(const [FinanceScope.accounts]);
    return account;
  }

  Future<AccountDetails> update(String id, Json changes) async {
    final account = await _api.update(id, changes);
    _changes.notify(const [FinanceScope.accounts]);
    return account;
  }

  Future<AccountDetails> save(String id, AccountInput input) => update(id, input.toJson());

  Future<AccountDetails> setArchived(String id, bool archived) => update(id, {'archived': archived});

  Future<AccountDetails> setIncludedInNetWorth(String id, bool include) =>
      update(id, {'include_in_net_worth': include});

  Future<void> remove(String id) async {
    await _api.delete(id);
    _changes.notify(const [FinanceScope.accounts]);
  }

  Future<ReconcileResult> reconcile(String id, Cents actualBalanceCents, DateTime? date) async {
    final result = await _api.reconcile(id, actualBalanceCents, date);
    _changes.notifyTransactions();
    return result;
  }
}

final accountsOverviewProvider = FutureProvider<AccountsOverview>((ref) async {
  ref.watchFinance(const [FinanceScope.accounts]);
  return ref.watch(accountsAdminApiProvider).list();
});

final accountDetailsProvider = FutureProvider.family<AccountDetails, String>((ref, id) async {
  final overview = await ref.watch(accountsOverviewProvider.future);
  return overview.find(id) ?? await ref.watch(accountsAdminApiProvider).get(id);
});

final accountHistoryProvider = FutureProvider.family<List<Transaction>, String>((ref, id) async {
  ref.watchFinance(const [FinanceScope.transactions]);
  final api = ref.watch(financeApiProvider);
  final reference = today();
  final from = DateTime(reference.year, reference.month, reference.day - accountHistoryDays);
  final query = {
    'account_id': [id],
    'from': isoDate(from),
  };
  final collected = <Transaction>[];
  String? cursor;
  for (var page = 0; page < accountHistoryMaxPages; page++) {
    final result = await api.transactions(query, cursor: cursor, perPage: accountHistoryPageSize);
    collected.addAll(result.data);
    cursor = result.nextCursor;
    if (!result.hasMore || cursor == null) break;
  }
  return collected;
});
