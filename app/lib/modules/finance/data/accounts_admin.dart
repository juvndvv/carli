import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import 'finance_api.dart';
import 'finance_changes.dart';
import 'finance_providers.dart';
import 'json.dart';
import 'models.dart';

const accountHistoryDays = 90;
const accountHistoryMaxPages = 5;
const accountHistoryPageSize = 200;
const accountIconChoices = ['landmark', 'piggy-bank', 'credit-card', 'banknote', 'wallet', 'coins', 'euro', 'building'];
const accountColorChoices = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8'];

class ReconcileResult {
  const ReconcileResult({
    required this.account,
    required this.adjustment,
    required this.differenceCents,
    required this.balanceCents,
  });

  factory ReconcileResult.fromJson(Json json) => ReconcileResult(
    account: Account.fromJson(json['account'] as Json),
    adjustment: json['adjustment'] is Json ? Transaction.fromJson(json['adjustment'] as Json) : null,
    differenceCents: intOf(json['difference_cents']),
    balanceCents: intOf(json['balance_cents']),
  );

  final Account account;
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
      'type': type.api,
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

String? cardSchedule(Account account) {
  final parts = [
    if (account.statementDay case final day?) 'Corte día $day',
    if (account.paymentDay case final day?) 'se carga el día $day',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String accountsSummaryLabel(List<Account> active) {
  final label = active.length == 1 ? '1 cuenta' : '${active.length} cuentas';
  return active.any((account) => account.isCreditCard) ? '$label · las tarjetas de crédito restan' : label;
}

String archivedAccountsLabel(int count) => count == 1 ? '1 cuenta archivada' : '$count cuentas archivadas';

Cents reconcileStartingBalance(Account account) => account.bank?.balanceCents ?? account.clearedBalanceCents;

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

BankBalanceSummary? bankBalanceSummary(AccountBankLink? link, {DateTime? now}) {
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

  Future<Account> get(String id) async => Account.fromJson((await _dio.get<Json>('$_base/$id')).data!['data'] as Json);

  Future<Account> create(Json input) async =>
      Account.fromJson((await _dio.post<Json>(_base, data: input)).data!['data'] as Json);

  Future<Account> update(String id, Json input) async =>
      Account.fromJson((await _dio.patch<Json>('$_base/$id', data: input)).data!['data'] as Json);

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

  Future<Account> create(AccountInput input) async {
    final account = await _api.create(input.toJson());
    _changes.notify(const [FinanceScope.accounts]);
    return account;
  }

  Future<Account> update(String id, Json changes) async {
    final account = await _api.update(id, changes);
    _changes.notify(const [FinanceScope.accounts]);
    return account;
  }

  Future<Account> save(String id, AccountInput input) => update(id, input.toJson());

  Future<Account> setArchived(String id, bool archived) => update(id, {'archived': archived});

  Future<Account> setIncludedInNetWorth(String id, bool include) => update(id, {'include_in_net_worth': include});

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

final accountDetailsProvider = FutureProvider.family<Account, String>((ref, id) async {
  final overview = await ref.watch(accountsProvider.future);
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
